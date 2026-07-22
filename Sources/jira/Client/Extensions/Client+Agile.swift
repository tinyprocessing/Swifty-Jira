import Foundation

extension Jira {
    /// Returns ALL boards for a project (paged, up to 100).
    func fetchAllBoards(projectKey: String) async -> [Board] {
        let path = "/rest/agile/1.0/board?projectKeyOrId=\(projectKey)&maxResults=100"
        let result: Result<BoardList, Error> = (try? await request(configuration: makeRequest(path))) ?? .failure(NSError())
        if case .success(let list) = result { return list.values ?? [] }
        return []
    }

    /// Finds the first scrum board for a project (legacy single-board path).
    func fetchBoard(projectKey: String) async -> Board? {
        let boards = await fetchAllBoards(projectKey: projectKey)
        return boards.first(where: { $0.type == "scrum" }) ?? boards.first
    }

    /// Returns the active sprint for a board (first one — for single-sprint contexts).
    func fetchActiveSprint(boardId: Int) async -> Sprint? {
        return (await fetchActiveSprints(boardId: boardId)).first
    }

    /// Returns ALL active sprints for a board.
    func fetchActiveSprints(boardId: Int) async -> [Sprint] {
        let path = "/rest/agile/1.0/board/\(boardId)/sprint?state=active&maxResults=20"
        let result: Result<SprintList, Error> = (try? await request(configuration: makeRequest(path))) ?? .failure(NSError())
        if case .success(let list) = result { return list.values ?? [] }
        return []
    }

    /// Returns the first future (next) sprint for a board, if any.
    func fetchNextSprint(boardId: Int) async -> Sprint? {
        let path = "/rest/agile/1.0/board/\(boardId)/sprint?state=future"
        let result: Result<SprintList, Error> = (try? await request(configuration: makeRequest(path))) ?? .failure(NSError())
        if case .success(let list) = result {
            return list.values?.first
        }
        return nil
    }

    /// Adds an existing issue to a sprint. Returns true on success.
    func addIssueToSprint(issueKey: String, sprintId: Int) async -> Bool {
        do {
            let params: [String: Any] = ["issues": [issueKey]]
            let req = makeRequestCustom("/rest/agile/1.0/sprint/\(sprintId)/issue", body: params)
            let (_, response) = try await URLSession.shared.data(for: req)
            let code = (response as? HTTPURLResponse)?.statusCode ?? -1
            if code == 204 {
                return true
            }
            fputs("[sprint] add failed, status \(code)\n", stderr)
            return false
        } catch {
            fputs("[sprint] error: \(error)\n", stderr)
            return false
        }
    }
}
