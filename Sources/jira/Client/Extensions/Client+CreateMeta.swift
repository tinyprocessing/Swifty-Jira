import Foundation

extension Jira {
    /// Prints the create-metadata for a project+issuetype as JSON: which fields
    /// are required, their customfield IDs, types, and allowedValues.
    /// This is how an agent learns what a `create` must include (Epic Link,
    /// Story Type, Application/Service, etc.) — IDs vary per instance/project.
    func createMeta(projectKey: String, issueType: String, raw: Bool, likeKey: String?) async {
        do {
            var fields: [String: Any]

            if let likeKey = likeKey {
                // editmeta on an existing issue — works even when the global
                // createmeta endpoint is disabled (common on newer Jira Server).
                let path = "/rest/api/2/issue/\(likeKey)/editmeta"
                let (data, response) = try await URLSession.shared.data(for: makeRequest(path))
                let code = (response as? HTTPURLResponse)?.statusCode ?? -1
                guard code == 200 else {
                    fputs("editmeta failed (status \(code)): \(String(data: data, encoding: .utf8) ?? "")\n", stderr)
                    Foundation.exit(1)
                }
                if raw { print(String(data: data, encoding: .utf8) ?? "{}"); return }
                guard let root = try JSONSerialization.jsonObject(with: data) as? [String: Any],
                      let f = root["fields"] as? [String: Any] else {
                    fputs("Unexpected editmeta shape; use --enable-raw to inspect.\n", stderr)
                    Foundation.exit(1)
                }
                fields = f
            } else {
                let encodedType = issueType.addingPercentEncoding(withAllowedCharacters: .urlQueryAllowed) ?? issueType
                let path = "/rest/api/2/issue/createmeta?projectKeys=\(projectKey)&issuetypeNames=\(encodedType)&expand=projects.issuetypes.fields"
                let (data, response) = try await URLSession.shared.data(for: makeRequest(path))
                let code = (response as? HTTPURLResponse)?.statusCode ?? -1
                guard code == 200 else {
                    fputs("createmeta failed (status \(code)): \(String(data: data, encoding: .utf8) ?? "")\n", stderr)
                    fputs("Tip: this Jira may disable global createmeta. Retry with --like <an-existing-issue-key> to read fields via editmeta.\n", stderr)
                    Foundation.exit(1)
                }
                if raw { print(String(data: data, encoding: .utf8) ?? "{}"); return }
                guard let root = try JSONSerialization.jsonObject(with: data) as? [String: Any],
                      let projects = root["projects"] as? [[String: Any]],
                      let project = projects.first,
                      let issuetypes = project["issuetypes"] as? [[String: Any]],
                      let it = issuetypes.first,
                      let f = it["fields"] as? [String: Any] else {
                    fputs("Unexpected createmeta shape; use --enable-raw to see the full payload.\n", stderr)
                    Foundation.exit(1)
                }
                fields = f
            }

            struct FieldInfo: Encodable {
                let id: String
                let name: String
                let required: Bool
                let type: String
                let custom: String?
                let allowedValues: [String]?
            }

            var infos: [FieldInfo] = []
            for (id, value) in fields {
                guard let f = value as? [String: Any] else { continue }
                let name = f["name"] as? String ?? id
                let required = f["required"] as? Bool ?? false
                let schema = f["schema"] as? [String: Any]
                let type = schema?["type"] as? String ?? "unknown"
                let custom = schema?["custom"] as? String
                var allowed: [String]?
                if let av = f["allowedValues"] as? [[String: Any]] {
                    allowed = av.compactMap { ($0["value"] as? String) ?? ($0["name"] as? String) }
                    if allowed?.isEmpty ?? true { allowed = nil }
                }
                infos.append(FieldInfo(id: id, name: name, required: required, type: type,
                                       custom: custom.flatMap { $0.components(separatedBy: ":").last },
                                       allowedValues: allowed))
            }
            // Required fields first, then alphabetical.
            infos.sort { ($0.required ? 0 : 1, $0.name) < ($1.required ? 0 : 1, $1.name) }

            // Detect nfeed/opaque fields that have no allowedValues — their
            // write-shape can only be learned by reading an existing issue.
            let opaqueRequired = infos.filter {
                $0.required && $0.allowedValues == nil &&
                ($0.custom?.contains("nfeed") == true || $0.type == "array" || $0.type == "any")
            }
            var hint = "Pass custom fields with --fields-json '{\"id\":value,...}' on `issue create`. "
                + "Epic Link = bare key string; selects use {\"value\":\"…\"} from allowedValues."
            if !opaqueRequired.isEmpty {
                let names = opaqueRequired.map { "\($0.id) (\($0.name))" }.joined(separator: ", ")
                hint += " WARNING: \(names) \(opaqueRequired.count == 1 ? "has" : "have") no allowedValues "
                    + "(opaque/nfeed type). To find the exact write-shape, read an existing issue: "
                    + "`swifty-jira issue export --key <EXISTING-KEY> --enable-raw` and inspect those field IDs. "
                    + "RECOMMENDED: use `issue clone --from <EXISTING-KEY>` instead of `create` — "
                    + "it copies these fields verbatim."
            }

            struct Output: Encodable {
                let project: String
                let issueType: String
                let requiredFields: [String]
                let opaqueRequiredFields: [String]
                let fields: [FieldInfo]
                let hint: String
            }
            let out = Output(
                project: projectKey,
                issueType: issueType,
                requiredFields: infos.filter { $0.required }.map { "\($0.id) (\($0.name))" },
                opaqueRequiredFields: opaqueRequired.map { "\($0.id) (\($0.name))" },
                fields: infos,
                hint: hint
            )
            let encoder = JSONEncoder()
            encoder.outputFormatting = [.prettyPrinted, .sortedKeys]
            if let d = try? encoder.encode(out) {
                print(String(data: d, encoding: .utf8) ?? "{}")
            }
        } catch {
            fputs("Error: \(error)\n", stderr)
            Foundation.exit(1)
        }
    }
}
