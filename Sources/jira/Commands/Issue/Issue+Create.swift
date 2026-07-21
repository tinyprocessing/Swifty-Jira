import ArgumentParser
import SwiftyTextTable

extension SwiftyJira.Issue {
    struct Create: AsyncParsableCommand {
        static var configuration = CommandConfiguration(
            abstract: "Create an issue. Use --like <KEY> to inherit required custom fields (Epic Link, App/Service, Story Type…) from an existing issue — simplest path for projects with opaque required fields."
        )

        @OptionGroup()
        var options: SwiftyJira.Options

        @Option(name: .long, default: "", help: "Parent key (Sub-task only)")
        var parent: String

        @Option(name: .long, help: "Summary / title")
        var summary: String

        @Option(name: .long, help: "Project key, e.g. MEM")
        var project: String

        @Option(name: .long, default: "", help: "Assignee login (default: current user)")
        var assignee: String

        @Option(name: .long, default: "Task", help: "Issue type: Task | Bug | Story | Sub-task")
        var type: String

        @Option(name: .long, default: "", help: "Description text")
        var description: String

        @Option(name: .long, default: nil, help: "Inherit required custom fields (Epic Link, Story Type, Application/Service…) from this existing issue key. Explicit --fields-json overrides individual inherited fields.")
        var like: String?

        @Option(name: .long, default: nil, help: "JSON object of extra/custom fields merged last, e.g. '{\"customfield_10211\":{\"value\":\"Technical Story\"}}'")
        var fieldsJson: String?

        @Option(name: .long, default: "", help: "Add to sprint: 'current' (active) or 'next' (first future). Empty = backlog.")
        var sprint: String

        @Flag(default: false, inversion: .prefixedEnableDisable, help: "Preview the POST body without creating anything")
        var dryRun: Bool

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
                    likeKey: like,
                    fieldsJSON: fieldsJson,
                    sprintTarget: target,
                    dryRun: dryRun
                )
            }
        }
    }
}
