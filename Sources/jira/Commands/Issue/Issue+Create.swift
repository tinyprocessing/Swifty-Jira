import ArgumentParser
import SwiftyTextTable

extension SwiftyJira.Issue {
    struct Create: AsyncParsableCommand {
        static var configuration = CommandConfiguration(
            abstract: "Create an issue. Parent is optional (Sub-task only). Use --sprint current|next and --fields-json for custom/required fields (Epic Link, Story Type, etc). Run `issue createmeta` first to see required fields."
        )

        @OptionGroup()
        var options: SwiftyJira.Options

        @Option(name: .long, default: "", help: "Parent key (Sub-task only)")
        var parent: String

        @Option(name: .long, help: "Summary / title")
        var summary: String

        @Option(name: .long, help: "Project key, e.g. MEM")
        var project: String

        @Option(name: .long, default: "", help: "Assignee login (default: unassigned)")
        var assignee: String

        @Option(name: .long, default: "Task", help: "Issue type: Task | Bug | Story | Sub-task")
        var type: String

        @Option(name: .long, default: "", help: "Description text")
        var description: String

        @Option(name: .long, default: nil, help: "JSON object of extra/custom fields merged into the create body, e.g. '{\"customfield_10211\":{\"value\":\"Technical Story\"},\"customfield_20400\":[\"16724030\"],\"customfield_10007\":\"MEM-7553\"}'")
        var fieldsJson: String?

        @Option(name: .long, default: "", help: "Add to sprint: 'current' (active) or 'next' (first future). Empty = no sprint.")
        var sprint: String

        mutating func runAsync() async throws {
            let client = try options.jiraClient()
            let target: Jira.SprintTarget
            switch sprint.lowercased() {
            case "current", "active": target = .active
            case "next", "future": target = .next
            default: target = .none
            }
            if await client.auth() {
                await client.create(
                    parent: parent,
                    summary: summary,
                    project: project,
                    assignee: assignee,
                    issueType: type,
                    description: description,
                    fieldsJSON: fieldsJson,
                    sprintTarget: target
                )
            }
        }
    }
}
