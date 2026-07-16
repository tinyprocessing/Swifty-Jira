import ArgumentParser

extension SwiftyJira.Issue {
    /// Clone an existing issue into a new one, copying its (writable) fields —
    /// including required custom fields — and overriding summary/description.
    struct Clone: AsyncParsableCommand {
        static var configuration = CommandConfiguration(
            abstract: "Clone an existing issue (copies required/custom fields), overriding summary/description. Use --enable-dry-run to preview the POST body first."
        )

        @OptionGroup()
        var options: SwiftyJira.Options

        @Option(name: .long, help: "Source issue key to clone from, e.g. MEM-8146")
        var from: String

        @Option(name: .long, default: nil, help: "New summary (default: 'CLONE: <source summary>')")
        var summary: String?

        @Option(name: .long, default: nil, help: "New description (default: copied from source)")
        var description: String?

        @Option(name: .long, default: nil, help: "Assignee login (default: current user)")
        var assignee: String?

        @Option(name: .long, default: "", help: "Add to sprint: 'current' or 'next'. Empty = backlog.")
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
                await client.cloneIssue(
                    source: from,
                    summary: summary,
                    description: description,
                    assignee: assignee,
                    sprintTarget: target,
                    dryRun: dryRun
                )
            }
        }
    }
}
