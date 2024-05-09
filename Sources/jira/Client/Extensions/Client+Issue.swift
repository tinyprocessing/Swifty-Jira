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
                    TextTableColumn(header: "Assignee"),
                    TextTableColumn(header: "Subtasks"),
                ], header: "Issue \(response.key ?? "")")
                let issue = response
                if let fields: IssueFields = issue.fields {
                    table.addRow(values: [
                        issue.key ?? "",
                        fields.created?.components(separatedBy: "T").first ?? "",
                        fields.summary ?? "",
                        fields.assignee?.name ?? "",
                        fields.subtasks?.count ?? "",
                    ])
                }
                print(table.render())
            case .failure:
                break
            }
        } catch {}
    }

    func issues() async {
        do {
            let result: Result<SearchIssues, Error> = try await request(configuration: makeRequest("/rest/api/2/search?jql=assignee=currentUser()+AND+status!=Done"))
            switch result {
            case let .success(response):
                var table = TextTable(columns: [
                    TextTableColumn(header: "Key"),
                    TextTableColumn(header: "Created"),
                    TextTableColumn(header: "Summary"),
                    TextTableColumn(header: "Assignee"),
                    TextTableColumn(header: "Subtasks"),
                ], header: "Issues for user")
                if let issues: [Issue] = response.issues {
                    for i in 0 ... issues.count - 1 {
                        let issue = issues[i]
                        if let fields: IssueFields = issue.fields {
                            table.addRow(values: [
                                issue.key ?? "",
                                fields.created?.components(separatedBy: "T").first ?? "",
                                fields.summary ?? "",
                                fields.assignee?.name ?? "",
                                fields.subtasks?.count ?? "",
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
}
