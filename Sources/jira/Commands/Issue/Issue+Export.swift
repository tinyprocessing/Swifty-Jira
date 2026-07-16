import ArgumentParser

extension SwiftyJira.Issue {
    /// Exports full issue context as JSON — perfect for piping to Claude.
    struct Export: AsyncParsableCommand {
        static var configuration = CommandConfiguration(
            abstract: "Export full issue context as JSON (for Claude / scripts)"
        )

        @OptionGroup()
        var options: SwiftyJira.Options

        @Option(name: .long, help: "Issue key, e.g. PROJ-123")
        var key: String

        @Flag(default: false, inversion: .prefixedEnableDisable, help: "Dump the raw Jira issue JSON (all fields, incl. custom fields)")
        var raw: Bool

        mutating func runAsync() async throws {
            let client = try options.jiraClient()
            if await client.auth() {
                if raw {
                    await client.exportRawIssue(key: key)
                } else {
                    await client.exportIssue(key: key)
                }
            }
        }
    }
}
