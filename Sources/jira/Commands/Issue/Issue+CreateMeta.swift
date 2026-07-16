import ArgumentParser

extension SwiftyJira.Issue {
    /// Discover which fields (incl. custom: Epic Link, Story Type, etc.) a
    /// create requires for a given project + issue type.
    struct CreateMeta: AsyncParsableCommand {
        static var configuration = CommandConfiguration(
            commandName: "createmeta",
            abstract: "Show required/available fields (incl. custom field IDs) for creating an issue"
        )

        @OptionGroup()
        var options: SwiftyJira.Options

        @Option(name: .long, help: "Project key, e.g. MEM")
        var project: String

        @Option(name: .long, default: "Story", help: "Issue type, e.g. Story | Task | Bug")
        var type: String

        @Flag(default: false, inversion: .prefixedEnableDisable, help: "Print the raw payload")
        var raw: Bool

        @Option(name: .long, default: nil, help: "Read fields from an existing issue's editmeta (use when global createmeta is disabled)")
        var like: String?

        mutating func runAsync() async throws {
            let client = try options.jiraClient()
            if await client.auth() {
                await client.createMeta(projectKey: project, issueType: type, raw: raw, likeKey: like)
            }
        }
    }
}
