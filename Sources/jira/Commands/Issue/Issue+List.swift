import ArgumentParser
import SwiftyTextTable

extension SwiftyJira.Issue {
    struct List: AsyncParsableCommand {
        static var configuration = CommandConfiguration(
            abstract: "List issues. Filters: undone (default), backlog, all, openSprints, openAndFutureSprints, or any status name. Use --jql for custom JQL."
        )

        @OptionGroup()
        var options: SwiftyJira.Options

        @Option(name: .long, default: "undone", help: "Preset filter: undone | backlog | all | openSprints | openAndFutureSprints | <status name>")
        var filter: String

        @Option(name: .long, default: nil, help: "Custom JQL query (overrides --filter)")
        var jql: String?

        @Flag(default: false, inversion: .prefixedEnableDisable, help: "Output as JSON instead of table")
        var json: Bool

        mutating func runAsync() async throws {
            let client = try options.jiraClient()
            if await client.auth() {
                await client.issues(filter: filter, customJQL: jql, asJSON: json)
            }
        }
    }
}
