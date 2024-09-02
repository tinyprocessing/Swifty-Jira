import AppKit
import Foundation
import SwiftyTextTable

extension Jira {
    func issue(id: String, viewInWeb: Bool = false) async {
        guard !viewInWeb else {
            if let url = URL(string: domain + "/browse/\(id)") {
                NSWorkspace.shared.open(url)
            }
            return
        }
        do {
            let result: Result<Issue, Error> = try await request(configuration: makeRequest("/rest/api/2/issue/\(id)"))
            switch result {
            case .success(let response):
                var table = TextTable(columns: [
                    TextTableColumn(header: "Key"),
                    TextTableColumn(header: "Created"),
                    TextTableColumn(header: "Summary"),
                    TextTableColumn(header: "Subtasks"),
                    TextTableColumn(header: "Status")
                ], header: "Issue \(response.key ?? "") -> \(response.fields?.assignee?.displayName ?? "")")
                let issue = response
                printIssue(issue: issue, table: &table)
                issue.fields?.subtasks?.forEach { printIssue(issue: $0, table: &table) }
                issue.fields?.issuelinks?.forEach { link in
                    if let outwardIssue = link.outwardIssue {
                        printIssue(issue: outwardIssue, table: &table)
                    }
                }
                print(table.render())
            case .failure:
                break
            }
        } catch {}
    }

    private func printIssue(issue: Issue, table: inout TextTable) {
        if let fields: IssueFields = issue.fields {
            var subtitleArray = splitStringIntoChunks(subtitle(fields.summary))
            if let nameAssignee = fields.assignee?.displayName {
                subtitleArray.append("\u{001B}[0;36mAssignee: \(nameAssignee) \u{001B}[0;0m")
            }
            table.addRow(values: [
                title(issue.key ?? "", type: fields.issuetype?.name ?? ""),
                fields.created?.components(separatedBy: "T").first ?? "",
                subtitleArray.first ?? "",
                fields.subtasks?.count ?? "",
                fields.status?.name ?? ""
            ])
            if subtitleArray.count > 1 {
                for i in 1..<subtitleArray.count {
                    table.addRow(values: [
                        "",
                        "",
                        subtitleArray[i],
                        "",
                        ""
                    ])
                }
            }
            if let parent = fields.parent {
                table.addRow(values: [
                    "",
                    "",
                    "\u{001B}[0;36mParent: \(parent.key ?? "") \u{001B}[0;0m",
                    "",
                    ""
                ])
            }
            table.addRow(values: [])
        }
    }

    func issues(filter: String) async {
        var filter = filter
        switch filter {
        case "undone":
            filter = "+AND+status!=done"
        case "backlog":
            filter =
                "+AND+project=*MEM*+AND+(sprint+is+EMPTY+OR+Sprint+not+in+(openSprints(),+futureSprints()))+AND+resolution+=+Unresolved+and+status+!=+Closed"
        case "all":
            filter = ""
        case "openSprints":
            filter = "+AND+Sprint+in+openSprints()"
        default:
            filter = "+AND+status=\(filter)"
        }
        let jql = "assignee=currentUser()" + filter
        do {
            let result: Result<SearchIssues, Error> =
                try await request(configuration: makeRequest("/rest/api/2/search?jql=\(jql)"))
            switch result {
            case .success(let response):
                var table = TextTable(columns: [
                    TextTableColumn(header: "Key"),
                    TextTableColumn(header: "Created"),
                    TextTableColumn(header: "Summary"),
                    TextTableColumn(header: "Subtasks"),
                    TextTableColumn(header: "Status")
                ], header: "Issues for user")
                if let issues: [Issue] = response.issues {
                    for i in 0...issues.count - 1 {
                        let issue = issues[i]
                        printIssue(issue: issue, table: &table)
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

    private func title(_ value: String?, type: String?) -> String {
        if let value = value, let type = type {
            if type == "Sub-task" {
                return "\u{001B}[0;37mST \u{001B}[0;0m" + value
            }
            if type == "Task" {
                return "\u{001B}[0;31mT \u{001B}[0;0m" + value
            }
            if type == "Bug" {
                return "\u{001B}[0;31mB \u{001B}[0;0m" + value
            }
            if type == "Story" {
                return "\u{001B}[0;33mS \u{001B}[0;0m" + value
            }
        }
        return (value ?? "")
    }

    private func subtitle(_ value: String?) -> String {
        if let value = value {
            return value
        }
        return ""
    }

    private func splitStringIntoChunks(_ input: String, chunkSize: Int = 42) -> [String] {
        let cleanedInput = input.trimmingCharacters(in: .whitespacesAndNewlines)
        var chunks: [String] = []
        var currentIndex = cleanedInput.startIndex
        while currentIndex < cleanedInput.endIndex {
            let endIndex = cleanedInput
                .index(currentIndex, offsetBy: chunkSize, limitedBy: cleanedInput.endIndex) ?? cleanedInput.endIndex
            let chunk = String(cleanedInput[currentIndex..<endIndex])
            chunks.append(chunk)
            currentIndex = endIndex
        }

        return chunks
    }
}
