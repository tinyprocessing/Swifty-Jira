import AppKit
import Foundation

extension Jira {
    // Fixed column widths for the issue tables (Summary is flexible).
    private var keyColWidth: Int { 13 }
    private var createdColWidth: Int { 10 }
    private var subtasksColWidth: Int { 4 }
    private var statusColWidth: Int { 12 }

    private func issueTable(title: String) -> Table {
        Table(title: title, columns: [
            Table.Column("Key", width: keyColWidth),
            Table.Column("Created", width: createdColWidth),
            Table.Column("Summary"),  // flexible
            Table.Column("Subs", width: subtasksColWidth),
            Table.Column("Status", width: statusColWidth)
        ])
    }

    /// Width available for the Summary column, given the current terminal.
    private var summaryWidth: Int {
        let chrome = 2 + 2 + 4 * 3  // borders + 5 columns
        let fixed = keyColWidth + createdColWidth + subtasksColWidth + statusColWidth
        return max(20, Terminal.width - chrome - fixed)
    }

    func issue(id: String, viewInWeb: Bool = false) async {
        guard !viewInWeb else {
            if let url = URL(string: domain + "/browse/\(id)") {
                NSWorkspace.shared.open(url)
            }
            return
        }
        guard let response = await fetchIssue(key: id) else {
            fputs("Failed to fetch issue \(id)\n", stderr)
            return
        }
        var table = issueTable(
            title: "Issue \(response.key ?? "") -> \(response.fields?.assignee?.displayName ?? "")"
        )
        addIssueRows(issue: response, table: &table)
        response.fields?.subtasks?.forEach { addIssueRows(issue: $0, table: &table) }
        response.fields?.issuelinks?.forEach { link in
            if let outward = link.outwardIssue { addIssueRows(issue: outward, table: &table) }
            if let inward = link.inwardIssue { addIssueRows(issue: inward, table: &table) }
        }
        print(table.render())
    }

    private func addIssueRows(issue: Issue, table: inout Table) {
        guard let fields = issue.fields else { return }
        let lines = wrap(fields.summary ?? "", width: summaryWidth)
        table.addRow([
            title(issue.key ?? "", type: fields.issuetype?.name ?? ""),
            fields.created?.components(separatedBy: "T").first ?? "",
            lines.first ?? "",
            "\(fields.subtasks?.count ?? 0)",
            fields.status?.name ?? ""
        ])
        for extra in lines.dropFirst() {
            table.addRow(["", "", extra, "", ""])
        }
        if let name = fields.assignee?.displayName {
            table.addRow(["", "", cyan("↳ \(name)"), "", ""])
        }
        if let parent = fields.parent?.key {
            table.addRow(["", "", cyan("⤴ parent: \(parent)"), "", ""])
        }
        table.addSeparator()
    }

    func issues(filter: String, customJQL: String? = nil, asJSON: Bool = false) async {
        guard let response = await fetchIssues(filter: filter, customJQL: customJQL) else {
            fputs("Failed to fetch issues\n", stderr)
            return
        }
        let issues = response.issues ?? []
        if asJSON {
            printIssuesJSON(issues: issues, total: response.total ?? 0)
        } else {
            var table = issueTable(title: "Issues for user (\(issues.count)/\(response.total ?? 0))")
            issues.forEach { addIssueRows(issue: $0, table: &table) }
            print(table.render())
        }
    }

    private func printIssuesJSON(issues: [Issue], total: Int) {
        struct IssueRow: Encodable {
            let key: String
            let summary: String
            let status: String
            let type: String
            let assignee: String?
            let priority: String?
            let created: String?
            let subtasksCount: Int
        }
        let rows = issues.compactMap { issue -> IssueRow? in
            guard let key = issue.key, let fields = issue.fields else { return nil }
            return IssueRow(
                key: key,
                summary: fields.summary ?? "",
                status: fields.status?.name ?? "",
                type: fields.issuetype?.name ?? "",
                assignee: fields.assignee?.displayName,
                priority: fields.priority?.name,
                created: fields.created?.components(separatedBy: "T").first,
                subtasksCount: fields.subtasks?.count ?? 0
            )
        }
        struct Output: Encodable {
            let total: Int
            let returned: Int
            let issues: [IssueRow]
        }
        let output = Output(total: total, returned: rows.count, issues: rows)
        let encoder = JSONEncoder()
        encoder.outputFormatting = [.prettyPrinted, .sortedKeys]
        if let data = try? encoder.encode(output) {
            print(String(data: data, encoding: .utf8) ?? "{}")
        }
    }

    // MARK: - Formatting helpers

    private func cyan(_ s: String) -> String { "\u{001B}[0;36m\(s)\u{001B}[0m" }

    private func title(_ value: String, type: String) -> String {
        let (label, color): (String, String)
        switch type {
        case "Sub-task": (label, color) = ("ST", "0;37")
        case "Task": (label, color) = ("T", "0;34")
        case "Bug": (label, color) = ("B", "0;31")
        case "Story": (label, color) = ("S", "0;33")
        default: return value
        }
        return "\u{001B}[\(color)m\(label)\u{001B}[0m \(value)"
    }

    /// Word-wraps `text` to `width` columns, breaking on spaces where possible.
    private func wrap(_ text: String, width: Int) -> [String] {
        let clean = text.trimmingCharacters(in: .whitespacesAndNewlines)
            .replacingOccurrences(of: "\n", with: " ")
            .replacingOccurrences(of: "\r", with: " ")
        guard !clean.isEmpty else { return [""] }
        guard width > 4 else { return [String(clean.prefix(width))] }

        var lines: [String] = []
        var current = ""
        for word in clean.split(separator: " ") {
            let w = String(word)
            if current.isEmpty {
                current = w
            } else if current.count + 1 + w.count <= width {
                current += " " + w
            } else {
                lines.append(current)
                current = w
            }
            // Hard-break a single word longer than width.
            while current.count > width {
                lines.append(String(current.prefix(width)))
                current = String(current.dropFirst(width))
            }
        }
        if !current.isEmpty { lines.append(current) }
        return lines
    }
}
