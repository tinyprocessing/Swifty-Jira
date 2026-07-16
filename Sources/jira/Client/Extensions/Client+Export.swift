import Foundation

extension Jira {
    /// Fetches full issue context and returns a Claude-friendly JSON export.
    func exportIssue(key: String) async {
        do {
            // Request with comments expanded
            let path = "/rest/api/2/issue/\(key)?expand=renderedFields&fields=summary,description,status,issuetype,priority,assignee,reporter,project,created,updated,parent,subtasks,issuelinks,labels,comment"
            let result: Result<Issue, Error> = try await request(configuration: makeRequest(path))
            switch result {
            case .success(let issue):
                let export = buildExport(from: issue, domain: domain)
                let encoder = JSONEncoder()
                encoder.outputFormatting = [.prettyPrinted, .sortedKeys]
                let data = try encoder.encode(export)
                print(String(data: data, encoding: .utf8) ?? "{}")
            case .failure(let error):
                fputs("Error fetching issue \(key): \(error)\n", stderr)
                exit(1)
            }
        } catch {
            fputs("Error: \(error)\n", stderr)
            exit(1)
        }
    }

    /// Dumps the raw Jira issue JSON (all fields, including custom fields).
    func exportRawIssue(key: String) async {
        do {
            let (data, response) = try await URLSession.shared.data(for: makeRequest("/rest/api/2/issue/\(key)"))
            let code = (response as? HTTPURLResponse)?.statusCode ?? -1
            guard code == 200 else {
                fputs("Failed to fetch \(key) (status \(code))\n", stderr)
                Foundation.exit(1)
            }
            // Pretty-print for readability.
            if let obj = try? JSONSerialization.jsonObject(with: data),
               let pretty = try? JSONSerialization.data(withJSONObject: obj, options: [.prettyPrinted, .sortedKeys]) {
                print(String(data: pretty, encoding: .utf8) ?? "{}")
            } else {
                print(String(data: data, encoding: .utf8) ?? "{}")
            }
        } catch {
            fputs("Error: \(error)\n", stderr)
            Foundation.exit(1)
        }
    }

    /// Adds a comment to an issue.
    func addComment(key: String, body: String) async {
        do {
            let parameters: [String: Any] = ["body": body]
            let request = makeRequestCustom("/rest/api/2/issue/\(key)/comment", body: parameters)
            let (data, response) = try await URLSession.shared.data(for: request)
            if let http = response as? HTTPURLResponse, http.statusCode == 201 {
                fputs("Comment added to \(key)\n", stderr)
                print("{\"status\":\"ok\",\"key\":\"\(key)\"}")
            } else {
                let body = String(data: data, encoding: .utf8) ?? ""
                fputs("Error adding comment: \(body)\n", stderr)
                exit(1)
            }
        } catch {
            fputs("Error: \(error)\n", stderr)
            exit(1)
        }
    }

    /// Updates issue fields (summary and/or description).
    func updateIssue(key: String, summary: String?, description: String?) async {
        guard summary != nil || description != nil else {
            fputs("Nothing to update — provide --summary or --description\n", stderr)
            return
        }
        do {
            var fields: [String: Any] = [:]
            if let s = summary { fields["summary"] = s }
            if let d = description { fields["description"] = d }
            let parameters: [String: Any] = ["fields": fields]
            let request = makeRequestCustom("/rest/api/2/issue/\(key)", body: parameters, httpMethod: "PUT")
            let (_, response) = try await URLSession.shared.data(for: request)
            if let http = response as? HTTPURLResponse, http.statusCode == 204 {
                fputs("Issue \(key) updated\n", stderr)
                print("{\"status\":\"ok\",\"key\":\"\(key)\"}")
            } else {
                fputs("Update failed (status \((response as? HTTPURLResponse)?.statusCode ?? -1))\n", stderr)
                exit(1)
            }
        } catch {
            fputs("Error: \(error)\n", stderr)
            exit(1)
        }
    }

    // MARK: - Private helpers

    private func buildExport(from issue: Issue, domain: String) -> IssueExport {
        let fields = issue.fields
        let key = issue.key ?? "?"

        let subtasks: [IssueExport.SubtaskExport] = (fields?.subtasks ?? []).compactMap { st in
            guard let stKey = st.key else { return nil }
            return IssueExport.SubtaskExport(
                key: stKey,
                summary: st.fields?.summary ?? "",
                status: st.fields?.status?.name ?? "",
                assignee: st.fields?.assignee?.displayName
            )
        }

        let linkedIssues: [IssueExport.LinkedIssue] = (fields?.issuelinks ?? []).compactMap { link in
            if let outward = link.outwardIssue, let outKey = outward.key {
                return IssueExport.LinkedIssue(
                    key: outKey,
                    summary: outward.fields?.summary ?? "",
                    status: outward.fields?.status?.name ?? "",
                    type: outward.fields?.issuetype?.name ?? "",
                    linkRelation: link.type?.outward ?? "outward"
                )
            }
            if let inward = link.inwardIssue, let inKey = inward.key {
                return IssueExport.LinkedIssue(
                    key: inKey,
                    summary: inward.fields?.summary ?? "",
                    status: inward.fields?.status?.name ?? "",
                    type: inward.fields?.issuetype?.name ?? "",
                    linkRelation: link.type?.inward ?? "inward"
                )
            }
            return nil
        }

        let comments: [IssueExport.CommentExport] = (fields?.comment?.comments ?? []).map { c in
            IssueExport.CommentExport(
                author: c.author?.displayName ?? c.author?.name ?? "?",
                created: c.created?.components(separatedBy: "T").first ?? c.created ?? "",
                body: c.body ?? ""
            )
        }

        let labels: [String] = []  // JSONAny labels — skip for now

        return IssueExport(
            key: key,
            summary: fields?.summary ?? "",
            description: fields?.description,
            status: fields?.status?.name ?? "",
            type: fields?.issuetype?.name ?? "",
            priority: fields?.priority?.name,
            assignee: fields?.assignee?.displayName,
            reporter: fields?.reporter?.displayName,
            project: fields?.project?.key,
            created: fields?.created?.components(separatedBy: "T").first,
            updated: fields?.updated?.components(separatedBy: "T").first,
            parent: fields?.parent?.key,
            parentSummary: fields?.parent?.fields?.summary,
            subtasks: subtasks,
            linkedIssues: linkedIssues,
            comments: comments,
            labels: labels,
            url: "\(domain)/browse/\(key)"
        )
    }
}
