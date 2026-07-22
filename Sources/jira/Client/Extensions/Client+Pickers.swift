import Foundation

/// Data-fetching for TUI pickers (sprint, epic, user).
/// Results stay in-memory only — never persisted to disk.
extension Jira {
    // MARK: - Sprints

    /// Returns active + future sprints across ALL scrum boards of the project.
    /// Deduplicates by sprint id so shared sprints appear only once.
    /// Ordered: active first (newest first within state), then future.
    func fetchPickerSprints(projectKey: String) async -> [(id: Int, name: String, state: String)] {
        let boards = await fetchAllBoards(projectKey: projectKey)
        let scrumBoards = boards.filter { $0.type == "scrum" }
        guard !scrumBoards.isEmpty else { return [] }

        var seen = Set<Int>()
        var active: [(id: Int, name: String, state: String)] = []
        var future: [(id: Int, name: String, state: String)] = []

        for board in scrumBoards {
            guard let boardId = board.id else { continue }
            // Active sprints — use fetchActiveSprints which returns all (not just first).
            for s in await fetchActiveSprints(boardId: boardId) {
                guard let id = s.id, let name = s.name, !seen.contains(id) else { continue }
                seen.insert(id)
                active.append((id: id, name: name, state: "active"))
            }
            // Future sprints.
            let futurePath = "/rest/agile/1.0/board/\(boardId)/sprint?state=future&maxResults=10"
            let futureResult: Result<SprintList, Error> =
                (try? await request(configuration: makeRequest(futurePath))) ?? .failure(NSError())
            if case .success(let list) = futureResult {
                for s in list.values ?? [] {
                    guard let id = s.id, let name = s.name, !seen.contains(id) else { continue }
                    seen.insert(id)
                    future.append((id: id, name: name, state: "future"))
                }
            }
        }
        // Active first (most recently started at top), then future.
        return active + future
    }

    // MARK: - Epics

    struct EpicItem {
        let key: String
        let summary: String
    }

    /// Returns open epics for the given project (up to 500).
    func fetchPickerEpics(projectKey: String) async -> [EpicItem] {
        let jql = "project=\(projectKey)+AND+issuetype=Epic+AND+resolution=Unresolved+ORDER+BY+updated+DESC"
        let path = "/rest/api/2/search?jql=\(jql)&maxResults=500&fields=summary"
        let result: Result<SearchIssues, Error> =
            (try? await request(configuration: makeRequest(path))) ?? .failure(NSError())
        if case .success(let r) = result {
            return (r.issues ?? []).compactMap { issue in
                guard let key = issue.key, let summary = issue.fields?.summary else { return nil }
                return EpicItem(key: key, summary: summary)
            }
        }
        return []
    }

    // MARK: - Users

    /// Searches users by display name / username. Returns up to 20 results.
    /// Call this on Enter (not per-keystroke) to avoid hammering the API.
    func searchUsers(query: String) async -> [JiraUser] {
        let encoded = query.addingPercentEncoding(withAllowedCharacters: .urlQueryAllowed) ?? query
        let path = "/rest/api/2/user/search?username=\(encoded)&maxResults=20"
        let result: Result<[JiraUser], Error> =
            (try? await request(configuration: makeRequest(path))) ?? .failure(NSError())
        if case .success(let users) = result { return users }
        return []
    }

    // MARK: - Epic Link field id

    /// Resolves the customfield id for "Epic Link" from editmeta of a sample
    /// issue (field whose name == "Epic Link"). Returns nil if not found.
    func epicLinkFieldId(sampleKey: String) async -> String? {
        guard let (data, response) = try? await URLSession.shared.data(for: makeRequest("/rest/api/2/issue/\(sampleKey)/editmeta")),
              (response as? HTTPURLResponse)?.statusCode == 200,
              let root = try? JSONSerialization.jsonObject(with: data) as? [String: Any],
              let fields = root["fields"] as? [String: Any] else { return nil }
        return fields.first(where: {
            ($1 as? [String: Any])?["name"] as? String == "Epic Link"
        })?.key
    }
}

// MARK: - Result helpers
private extension Result {
    func flatMap<U>(_ transform: (Success) -> U?) -> U? {
        if case .success(let v) = self { return transform(v) }
        return nil
    }
}
