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

    /// Clone variant that returns the new key (for TUI use — must not exit/print).
    func cloneIssueReturning(
        source key: String,
        summary: String?,
        description: String?,
        assignee: String?
    ) async -> (key: String, project: String)? {
        guard let rawFields = await rawIssueFields(key: key) else { return nil }
        guard let writable = await editableFieldIDs(key: key) else { return nil }
        guard let project = (rawFields["project"] as? [String: Any])?["key"] as? String else { return nil }

        let hardStrip: Set<String> = [
            "customfield_10005",
            "comment", "attachment", "worklog", "issuelinks", "subtasks",
            "reporter", "assignee", "summary", "description", "issuetype", "project"
        ]
        var newFields: [String: Any] = [:]
        for (id, value) in rawFields {
            guard writable.contains(id), !hardStrip.contains(id) else { continue }
            if let normalized = normalizeForWrite(value) { newFields[id] = normalized }
        }
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
        if let me = await currentUsername() {
            newFields["reporter"] = ["name": me]
            newFields["assignee"] = ["name": assignee ?? me]
        } else if let a = assignee {
            newFields["assignee"] = ["name": a]
        }
        guard let newKey = await createWithFieldsReturning(newFields, project: project, sprintTarget: .none) else { return nil }
        return (key: newKey, project: project)
    }
}
