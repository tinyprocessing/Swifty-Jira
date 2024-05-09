import ArgumentParser
import SwiftyTextTable

extension SwiftyJira.Issue {
    struct List: AsyncParsableCommand {
        static var configuration = CommandConfiguration(
            abstract: "list"
        )

        @OptionGroup()
        var options: SwiftyJira.Options

        @Option(name: .long, default: "undone" ,help: "Issue Key")
        var filter: String

        mutating func runAsync() async throws {
            let client = try options.jiraClient()
            if await client.auth() {
                await client.issues(filter: filter)
            }
        }
    }
}
