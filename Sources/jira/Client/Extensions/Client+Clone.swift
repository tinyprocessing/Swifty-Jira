import Foundation

extension Jira {
    /// Clones an existing issue into a new one, copying only the fields that are
    /// writable on create (per the source's editmeta), normalizing each by its
    /// type, and letting the caller override summary / description / assignee.
    ///
    /// Sprint, comments, attachments, links and system fields are stripped.
    /// Reporter defaults to the current user, not the source's reporter.
    func cloneIssue(
        source key: String,
        summary: String?,
        description: String?,
        assignee: String?,
        sprintTarget: SprintTarget,
        dryRun: Bool
    ) async {
        // 1. Raw source fields (real custom-field values).
        guard let rawFields = await rawIssueFields(key: key) else {
            fputs("Failed to read source issue \(key)\n", stderr)
            Foundation.exit(1)
        }
        // 2. Writable field ids on create (from the source's editmeta).
        guard let writable = await editableFieldIDs(key: key) else {
            fputs("Failed to read editmeta for \(key)\n", stderr)
            Foundation.exit(1)
        }
        // 3. Project key (required, and drives sprint lookup).
        guard let project = (rawFields["project"] as? [String: Any])?["key"] as? String else {
            fputs("Source issue has no project key\n", stderr)
            Foundation.exit(1)
        }

        // Never copy these even if editmeta lists them.
        let hardStrip: Set<String> = [
            "customfield_10005",  // Sprint (greenhopper — set via --sprint instead)
            "comment", "attachment", "worklog", "issuelinks", "subtasks",
            "reporter", "assignee", "summary", "description", "issuetype", "project"
        ]

        var newFields: [String: Any] = [:]
        for (id, value) in rawFields {
            guard writable.contains(id), !hardStrip.contains(id) else { continue }
            if let normalized = normalizeForWrite(value) {
                newFields[id] = normalized
            }
        }

        // Required / overridable system fields.
        newFields["project"] = ["key": project]
        newFields["issuetype"] = (rawFields["issuetype"] as? [String: Any]).flatMap { it -> [String: Any]? in
            if let name = it["name"] as? String { return ["name": name] }
            if let id = it["id"] as? String { return ["id": id] }
            return nil
        } ?? ["name": "Task"]
        newFields["summary"] = summary ?? ((rawFields["summary"] as? String).map { "CLONE: \($0)" } ?? "Cloned from \(key)")
        if let description = description {
            newFields["description"] = description
        } else if let d = rawFields["description"] as? String {
            newFields["description"] = d
        }
        // Reporter = current user (source reporter may be someone else).
        if let me = await currentUsername() {
            newFields["reporter"] = ["name": me]
            newFields["assignee"] = ["name": assignee ?? me]
        } else if let assignee = assignee {
            newFields["assignee"] = ["name": assignee]
        }

        if dryRun {
            fputs("Dry run — the following fields would be POSTed to create:\n", stderr)
            let encoder = JSONEncoder()
            encoder.outputFormatting = [.prettyPrinted, .sortedKeys]
            // Re-encode via JSONSerialization since values are [String:Any].
            if let data = try? JSONSerialization.data(withJSONObject: ["fields": newFields], options: [.prettyPrinted, .sortedKeys]) {
                print(String(data: data, encoding: .utf8) ?? "{}")
            }
            return
        }

        await createWithFields(newFields, project: project, sprintTarget: sprintTarget)
    }

    // MARK: - helpers

    private func rawIssueFields(key: String) async -> [String: Any]? {
        guard let (data, response) = try? await URLSession.shared.data(for: makeRequest("/rest/api/2/issue/\(key)")),
              (response as? HTTPURLResponse)?.statusCode == 200,
              let root = try? JSONSerialization.jsonObject(with: data) as? [String: Any],
              let fields = root["fields"] as? [String: Any] else {
            return nil
        }
        return fields
    }

    private func editableFieldIDs(key: String) async -> Set<String>? {
        guard let (data, response) = try? await URLSession.shared.data(for: makeRequest("/rest/api/2/issue/\(key)/editmeta")),
              (response as? HTTPURLResponse)?.statusCode == 200,
              let root = try? JSONSerialization.jsonObject(with: data) as? [String: Any],
              let fields = root["fields"] as? [String: Any] else {
            return nil
        }
        return Set(fields.keys)
    }

    private func currentUsername() async -> String? {
        if case .success(let me) = (try? await request(configuration: makeRequest("/rest/api/2/myself")) as Result<UserModel, Error>) ?? .failure(NSError()) {
            return me.name
        }
        return nil
    }

    /// Reduce a read value to a valid write value per its shape.
    /// - option/select/user/priority/component objects -> {"id":…} (or {"name":…} for users)
    /// - arrays -> map each element
    /// - scalars (String/Int/Bool incl. Epic Link bare key, nfeed ["id"]) -> as-is
    /// - greenhopper/toString junk or null -> dropped (returns nil)
    private func normalizeForWrite(_ value: Any) -> Any? {
        if value is NSNull { return nil }
        if let s = value as? String {
            // Drop greenhopper sprint toString values just in case.
            if s.contains("com.atlassian.greenhopper") { return nil }
            return s
        }
        if value is Int || value is Double || value is Bool { return value }
        if let arr = value as? [Any] {
            let mapped = arr.compactMap { normalizeForWrite($0) }
            return mapped.isEmpty ? nil : mapped
        }
        if let dict = value as? [String: Any] {
            // Users are keyed by name; everything else by id.
            if dict["accountId"] != nil || (dict["name"] != nil && dict["emailAddress"] != nil) {
                if let name = dict["name"] as? String { return ["name": name] }
            }
            if let id = dict["id"] { return ["id": id] }
            if let name = dict["name"] as? String { return ["name": name] }
            if let value = dict["value"] as? String { return ["value": value] }
            return nil
        }
        return nil
    }
}
