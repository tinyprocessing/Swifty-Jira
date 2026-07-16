import ArgumentParser

extension SwiftyJira.Issue {
    struct AddComment: AsyncParsableCommand {
        static var configuration = CommandConfiguration(
            commandName: "comment",
            abstract: "Add a comment to an issue"
        )

        @OptionGroup()
        var options: SwiftyJira.Options

        @Option(name: .long, help: "Issue key, e.g. PROJ-123")
        var key: String

        @Option(name: .long, help: "Comment body text")
        var body: String

        mutating func runAsync() async throws {
            let client = try options.jiraClient()
            if await client.auth() {
                await client.addComment(key: key, body: body)
            }
        }
    }
}
