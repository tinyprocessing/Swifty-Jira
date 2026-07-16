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

    /// Creates an issue. `parent` is optional (only for sub-tasks).
    /// `fieldsJSON` is an optional JSON object of extra/custom fields merged into
    /// the create body (e.g. Epic Link, Story Type, Application/Service).
    func create(
        parent: String,
        summary: String,
        project: String,
        assignee: String,
        issueType: String = "Sub-task",
        description: String = "",
        fieldsJSON: String? = nil,
        sprintTarget: SprintTarget = .none
    ) async {
        do {
            var fields: [String: Any] = [
                "summary": summary,
                "issuetype": ["name": issueType],
                "project": ["key": project]
            ]
            if !assignee.isEmpty {
                fields["assignee"] = ["name": assignee]
            }
            if !parent.isEmpty {
                fields["parent"] = ["key": parent]
            }
            if !description.isEmpty {
                fields["description"] = description
            }

            // Merge custom fields (Epic Link, Story Type, Application/Service, …).
            if let fieldsJSON = fieldsJSON, !fieldsJSON.isEmpty {
                guard let data = fieldsJSON.data(using: .utf8),
                      let extra = try? JSONSerialization.jsonObject(with: data) as? [String: Any] else {
                    fputs("--fields-json must be a JSON object, e.g. '{\"customfield_10211\":{\"value\":\"Technical Story\"}}'\n", stderr)
                    Foundation.exit(1)
                }
                for (k, v) in extra { fields[k] = v }
            }

            await createWithFields(fields, project: project, sprintTarget: sprintTarget)
        } catch {
            fputs("Error: \(error)\n", stderr)
            Foundation.exit(1)
        }
    }

    /// Core create: POSTs a fully-built `fields` dict, then optionally adds to a
    /// sprint. Shared by `create` (from flags) and `clone` (from a source issue).
    func createWithFields(_ fields: [String: Any], project: String, sprintTarget: SprintTarget) async {
        do {
            let parameters: [String: Any] = ["fields": fields]
            let request = makeRequestCustom("/rest/api/2/issue", body: parameters)
            let (data, response) = try await URLSession.shared.data(for: request)
            let code = (response as? HTTPURLResponse)?.statusCode ?? -1
            guard code == 201, let created = try? JSONDecoder().decode(CreateResult.self, from: data), let newKey = created.key else {
                let body = String(data: data, encoding: .utf8) ?? ""
                fputs("Create failed (status \(code)): \(body)\n", stderr)
                Foundation.exit(1)
            }

            fputs("Created \(newKey)\n", stderr)

            switch sprintTarget {
            case .none:
                break
            case .active, .next:
                await addToSprint(newKey: newKey, project: project, target: sprintTarget)
            }

            print("{\"status\":\"ok\",\"key\":\"\(newKey)\",\"url\":\"\(domain)/browse/\(newKey)\"}")
        } catch {
            fputs("Error: \(error)\n", stderr)
            Foundation.exit(1)
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
