import Foundation

extension Jira {
    struct CreateResult: Codable {
        let id: String?
        let key: String?
    }

    /// Which sprint (if any) to add the new issue to after creation.
    enum SprintTarget {
        case none
        case active
        case next  // first future sprint
    }

    /// Creates an issue.
    /// - `likeKey`: inherit required custom fields from this existing issue
    ///   (Application/Service, Story Type, Epic Link…). Merged before `fieldsJSON`.
    /// - `fieldsJSON`: JSON object of additional/override custom fields.
    /// - `dryRun`: print the POST body without actually creating.
    func create(
        parent: String,
        summary: String,
        project: String,
        assignee: String,
        issueType: String = "Task",
        description: String = "",
        likeKey: String? = nil,
        fieldsJSON: String? = nil,
        sprintTarget: SprintTarget = .none,
        dryRun: Bool = false
    ) async {
        do {
            var fields: [String: Any] = [
                "summary": summary,
                "issuetype": ["name": issueType],
                "project": ["key": project]
            ]

            // 1. Inherit writable custom fields from --like reference issue.
            if let likeKey = likeKey {
                if let inherited = await inheritedCustomFields(from: likeKey) {
                    for (k, v) in inherited { fields[k] = v }
                    fputs("Inherited \(inherited.count) custom fields from \(likeKey)\n", stderr)
                } else {
                    fputs("Warning: could not read fields from \(likeKey); continuing without inherited fields.\n", stderr)
                }
            }

            // 2. System fields (override anything inherited).
            if let me = await currentUsername() {
                fields["reporter"] = ["name": me]
            }
            let effectiveAssignee = !assignee.isEmpty ? assignee : (await currentUsername() ?? "")
            if !effectiveAssignee.isEmpty {
                fields["assignee"] = ["name": effectiveAssignee]
            }
            if !parent.isEmpty { fields["parent"] = ["key": parent] }
            if !description.isEmpty { fields["description"] = description }

            // 3. Explicit --fields-json overrides last.
            if let fieldsJSON = fieldsJSON, !fieldsJSON.isEmpty {
                guard let data = fieldsJSON.data(using: .utf8),
                      let extra = try? JSONSerialization.jsonObject(with: data) as? [String: Any] else {
                    fputs("--fields-json must be a JSON object\n", stderr)
                    Foundation.exit(1)
                }
                for (k, v) in extra { fields[k] = v }
            }

            if dryRun {
                fputs("Dry run — POST body:\n", stderr)
                if let data = try? JSONSerialization.data(withJSONObject: ["fields": fields], options: [.prettyPrinted, .sortedKeys]) {
                    print(String(data: data, encoding: .utf8) ?? "{}")
                }
                return
            }

            await createWithFields(fields, project: project, sprintTarget: sprintTarget)
        } catch {
            fputs("Error: \(error)\n", stderr)
            Foundation.exit(1)
        }
    }

    /// Returns normalized custom fields from an existing issue suitable for
    /// a create POST (strips system/sprint/comment fields, normalizes shapes).
    private func inheritedCustomFields(from key: String) async -> [String: Any]? {
        guard let rawFields = await rawIssueFields(key: key),
              let writable = await editableFieldIDs(key: key) else { return nil }

        let strip: Set<String> = [
            "customfield_10005",  // Sprint (greenhopper, set via --sprint)
            "comment", "attachment", "worklog", "issuelinks", "subtasks",
            "reporter", "assignee", "summary", "description", "issuetype",
            "project", "status", "resolution", "created", "updated",
            "creator", "votes", "watches", "progress", "aggregateprogress",
            "lastViewed", "workratio", "timespent", "timeoriginalestimate",
            "aggregatetimespent", "aggregatetimeoriginalestimate"
        ]

        var result: [String: Any] = [:]
        for (id, value) in rawFields {
            guard writable.contains(id), !strip.contains(id) else { continue }
            // Only copy customfield_* and a few non-system writable fields.
            guard id.hasPrefix("customfield_") || id == "labels" || id == "priority" || id == "duedate" else { continue }
            if let normalized = normalizeForWrite(value) {
                result[id] = normalized
            }
        }
        return result
    }

    /// Core create: POSTs a fully-built `fields` dict, then optionally adds to a
    /// sprint. CLI version — prints JSON to stdout and exits on error.
    func createWithFields(_ fields: [String: Any], project: String, sprintTarget: SprintTarget) async {
        if let key = await createWithFieldsReturning(fields, project: project, sprintTarget: sprintTarget) {
            print("{\"status\":\"ok\",\"key\":\"\(key)\",\"url\":\"\(domain)/browse/\(key)\"}")
        } else {
            Foundation.exit(1)
        }
    }

    /// Core create returning the new issue key (or nil on failure).
    /// Used by both the CLI path and the TUI (which must not call exit/print).
    @discardableResult
    func createWithFieldsReturning(_ fields: [String: Any], project: String, sprintTarget: SprintTarget) async -> String? {
        do {
            let parameters: [String: Any] = ["fields": fields]
            let request = makeRequestCustom("/rest/api/2/issue", body: parameters)
            let (data, response) = try await URLSession.shared.data(for: request)
            let code = (response as? HTTPURLResponse)?.statusCode ?? -1
            guard code == 201, let created = try? JSONDecoder().decode(CreateResult.self, from: data), let newKey = created.key else {
                let body = String(data: data, encoding: .utf8) ?? ""
                fputs("Create failed (status \(code)): \(body)\n", stderr)
                return nil
            }

            fputs("Created \(newKey)\n", stderr)

            switch sprintTarget {
            case .none: break
            case .active, .next:
                await addToSprint(newKey: newKey, project: project, target: sprintTarget)
            }
            return newKey
        } catch {
            fputs("Error: \(error)\n", stderr)
            return nil
        }
    }

    private func addToSprint(newKey: String, project: String, target: SprintTarget) async {
        guard let board = await fetchBoard(projectKey: project), let boardId = board.id else {
            fputs("Warning: no board found for \(project); issue created but not added to a sprint.\n", stderr)
            return
        }
        let sprint: Sprint?
        switch target {
        case .next:
            sprint = await fetchNextSprint(boardId: boardId)
        default:
            sprint = await fetchActiveSprint(boardId: boardId)
        }
        guard let sprint = sprint, let sprintId = sprint.id else {
            let which = target == .next ? "future" : "active"
            fputs("Warning: no \(which) sprint found for \(project); issue created but not added to a sprint.\n", stderr)
            return
        }
        if await addIssueToSprint(issueKey: newKey, sprintId: sprintId) {
            fputs("Added \(newKey) to sprint \"\(sprint.name ?? "")\" (id \(sprintId))\n", stderr)
        }
    }
}
