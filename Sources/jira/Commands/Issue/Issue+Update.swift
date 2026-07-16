import ArgumentParser

extension SwiftyJira.Issue {
    struct Update: AsyncParsableCommand {
        static var configuration = CommandConfiguration(
            abstract: "Update issue fields (summary, description)"
        )

        @OptionGroup()
        var options: SwiftyJira.Options

        @Option(name: .long, help: "Issue key, e.g. PROJ-123")
        var key: String

        @Option(name: .long, default: nil, help: "New summary text")
        var summary: String?

        @Option(name: .long, default: nil, help: "New description text")
        var description: String?

        mutating func runAsync() async throws {
            let client = try options.jiraClient()
            if await client.auth() {
                await client.updateIssue(key: key, summary: summary, description: description)
            }
        }
    }
}
