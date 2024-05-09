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
        if filter == "undone" {
            filter = "+AND+status!=Done"
        } else if filter == "all" {
           filter = ""
        }else {
          filter = "+AND+status=" + filter
        }
        var jql: String = "assignee=currentUser()" + filter
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
}
