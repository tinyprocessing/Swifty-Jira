import Foundation

extension Jira {
    func create(parent: String, summary: String, project: String, assignee: String) async {
        do {
            let parameters: [String: Any] = [
                "fields": [
                    "summary": summary,
                    "issuetype": [
                        "name": "Sub-task",
                    ],
                    "parent": [
                        "key": parent,
                    ],
                    "project": [
                        "key": project,
                    ],
                    "assignee": [
                        "name": assignee,
                    ],
                ],
            ]
            print(parameters)
            let request = makeRequestCustom("/rest/api/2/issue", body: parameters)
            let (data, _) = try await URLSession.shared.data(for: request)
            print(String(data: data, encoding: .utf8) ?? "")
        } catch {
            print(error)
        }
    }
}
