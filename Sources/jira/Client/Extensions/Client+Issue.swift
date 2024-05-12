import Foundation
import SwiftyTextTable

extension Jira {
    func issue(id: String) async {
        do {
            let result: Result<Issue, Error> = try await request(configuration: makeRequest("/rest/api/2/issue/\(id)"))
            switch result {
            case let .success(response):
                var table = TextTable(columns: [
                    TextTableColumn(header: "Key"),
                    TextTableColumn(header: "Created"),
                    TextTableColumn(header: "Summary"),
                    TextTableColumn(header: "Subtasks"),
                    TextTableColumn(header: "Status"),
                ], header: "Issue \(response.key ?? "") -> \(response.fields?.assignee?.displayName ?? "")")
                let issue = response
                if let fields: IssueFields = issue.fields {
                    table.addRow(values: [
                        issue.key ?? "",
                        fields.created?.components(separatedBy: "T").first ?? "",
                        fields.summary ?? "",
                        fields.subtasks?.count ?? "",
                        fields.status?.name ?? "",
                    ])
                }
                print(table.render())
            case .failure:
                break
            }
        } catch {}
    }

    func issues(filter: String) async {
        var filter = filter
        switch filter {
        case "undone":
            filter = "+AND+status!=done"
        case "all":
            filter = ""
        default:
            filter = "+AND+status=\(filter)"
        }
        let jql = "assignee=currentUser()" + filter
        do {
            let result: Result<SearchIssues, Error> = try await request(configuration: makeRequest("/rest/api/2/search?jql=\(jql)"))
            switch result {
            case let .success(response):
                var table = TextTable(columns: [
                    TextTableColumn(header: "Key"),
                    TextTableColumn(header: "Created"),
                    TextTableColumn(header: "Summary"),
                    TextTableColumn(header: "Subtasks"),
                    TextTableColumn(header: "Status"),
                ], header: "Issues for user")
                if let issues: [Issue] = response.issues {
                    for i in 0 ... issues.count - 1 {
                        let issue = issues[i]
                        if let fields: IssueFields = issue.fields {
                            table.addRow(values: [
                                issue.key ?? "",
                                fields.created?.components(separatedBy: "T").first ?? "",
                                fields.summary ?? "",
                                fields.subtasks?.count ?? "",
                                fields.status?.name ?? "",
                            ])
                        }
                    }
                }
                print(table.render())
            case .failure:
                print("failure")
            }
        } catch {
            print(error)
        }
    }

    private func makeTransition(key: String, resolution: String, transition: String) async {
        do {
            var parameters: [String: Any] = [
                "update": [
                    "comment": [
                        [
                            "add": [
                                "body": "swifty-jira",
                            ],
                        ],
                    ],
                ],
                "transition": [
                    "id": transition,
                ],
            ]

            if !resolution.isEmpty {
                parameters["fields"] = [
                    "resolution": [
                        "name": resolution,
                    ],
                ]
            }

            let request = makeRequestPOST("/rest/api/2/issue/\(key)/transitions", body: parameters)
            let (data, _) = try await URLSession.shared.data(for: request)
            await issue(id: key)
        } catch {
            print(error)
        }
    }

    func transition(to status: String, key: String, resolution: String) async {
        do {
            let result: Result<Transition, Error> =
                try await request(configuration: makeRequest("/rest/api/2/issue/\(key)/transitions?expand=transitions.fields"))
            switch result {
            case let .success(response):
                var transitionValue: String?
                var resolutionValue: String?
                response.transitions?.forEach { transition in
                    if (transition.name ?? "").lowercased() == status.lowercased() {
                        print("You selected: \(transition.name ?? ""), with id: \(transition.id ?? "")")
                        if transition.fields?.resolution?.allowedValues?.isEmpty ?? true {
                            transitionValue = transition.id
                            resolutionValue = ""
                        }
                        transition.fields?.resolution?.allowedValues?.forEach { value in
                            if (value.name ?? "").lowercased() == resolution.lowercased() {
                                print("With resolution: \(value.id ?? "") -> \(value.name ?? "")")
                                transitionValue = transition.id
                                resolutionValue = value.name
                            }
                        }
                    }
                }

                if let transitionValue = transitionValue, let resolutionValue = resolutionValue {
                    await makeTransition(key: key,
                                         resolution: resolutionValue,
                                         transition: transitionValue)
                }
            case .failure:
                print("failure")
            }
        } catch {
            print(error)
        }
    }

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
            let request = makeRequestPOST("/rest/api/2/issue", body: parameters)
            let (data, _) = try await URLSession.shared.data(for: request)
            print(String(data: data, encoding: .utf8) ?? "")
        } catch {
            print(error)
        }
    }
}
