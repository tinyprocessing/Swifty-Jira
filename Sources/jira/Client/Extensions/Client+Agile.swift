import Foundation

extension Jira {
    /// Finds the first scrum board for a project.
    func fetchBoard(projectKey: String) async -> Board? {
        let path = "/rest/agile/1.0/board?projectKeyOrId=\(projectKey)"
        let result: Result<BoardList, Error> = (try? await request(configuration: makeRequest(path))) ?? .failure(NSError())
        if case .success(let list) = result {
            return list.values?.first(where: { $0.type == "scrum" }) ?? list.values?.first
        }
        return nil
    }

    /// Returns the active sprint for a board, if any.
    func fetchActiveSprint(boardId: Int) async -> Sprint? {
        let path = "/rest/agile/1.0/board/\(boardId)/sprint?state=active"
        let result: Result<SprintList, Error> = (try? await request(configuration: makeRequest(path))) ?? .failure(NSError())
        if case .success(let list) = result {
            return list.values?.first
        }
        return nil
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
