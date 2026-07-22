import Foundation

extension Jira {
    /// One-shot JSON snapshot for AI agents: who am I, active sprint, my open issues.
    func exportContext(projectKey: String?) async {
        struct SprintInfo: Encodable {
            let id: Int
            let name: String
            let state: String
            let startDate: String?
            let endDate: String?
            let goal: String?
            let boardId: Int?
        }
        struct IssueRow: Encodable {
            let key: String
            let summary: String
            let status: String
            let type: String
            let priority: String?
        }
        struct ContextOutput: Encodable {
            let user: UserInfo
            let project: String?
            let activeSprint: SprintInfo?    // kept for back-compat (first active sprint)
            let activeSprints: [SprintInfo]  // all active sprints across all boards
            let myOpenIssues: [IssueRow]
            let hint: String
        }
        struct UserInfo: Encodable {
            let displayName: String?
            let login: String?
            let email: String?
            let key: String?
        }

        // 1. Who am I
        var user = UserInfo(displayName: nil, login: nil, email: nil, key: nil)
        if case .success(let me) = (try? await request(configuration: makeRequest("/rest/api/2/myself")) as Result<UserModel, Error>) ?? .failure(NSError()) {
            user = UserInfo(displayName: me.displayName, login: me.name, email: me.emailAddress, key: me.key)
        }

        // 2. All active sprints across all scrum boards of the project.
        var allActiveSprints: [SprintInfo] = []
        if let projectKey = projectKey {
            let boards = await fetchAllBoards(projectKey: projectKey)
            var seen = Set<Int>()
            for board in boards.filter({ $0.type == "scrum" }) {
                guard let boardId = board.id else { continue }
                for sprint in await fetchActiveSprints(boardId: boardId) {
                    guard let sid = sprint.id, !seen.contains(sid) else { continue }
                    seen.insert(sid)
                    allActiveSprints.append(SprintInfo(
                        id: sid, name: sprint.name ?? "", state: sprint.state ?? "",
                        startDate: sprint.startDate?.components(separatedBy: "T").first,
                        endDate: sprint.endDate?.components(separatedBy: "T").first,
                        goal: sprint.goal, boardId: boardId
                    ))
                }
            }
        }
        let sprintInfo = allActiveSprints.first

        // 3. My open issues
        var rows: [IssueRow] = []
        let jql = "assignee=currentUser()+AND+status!=Done+AND+status!=Closed+AND+status!=%22Dev+Complete%22"
        if case .success(let search) = (try? await request(configuration: makeRequest("/rest/api/2/search?jql=\(jql)")) as Result<SearchIssues, Error>) ?? .failure(NSError()) {
            rows = (search.issues ?? []).compactMap { issue in
                guard let key = issue.key, let f = issue.fields else { return nil }
                return IssueRow(
                    key: key,
                    summary: f.summary ?? "",
                    status: f.status?.name ?? "",
                    type: f.issuetype?.name ?? "",
                    priority: f.priority?.name
                )
            }
        }

        let hint = "Use `swifty-jira issue export --key <KEY>` for full detail on any issue. Use `swifty-jira issue create` to add a task (pass --sprint-current to drop it into the active sprint)."
        let output = ContextOutput(
            user: user,
            project: projectKey,
            activeSprint: sprintInfo,
            activeSprints: allActiveSprints,
            myOpenIssues: rows,
            hint: hint
        )

        let encoder = JSONEncoder()
        encoder.outputFormatting = [.prettyPrinted, .sortedKeys]
        if let data = try? encoder.encode(output) {
            print(String(data: data, encoding: .utf8) ?? "{}")
        }
    }
}
