import ArgumentParser
import SwiftyTextTable

extension SwiftyJira.Issue {
    struct Assignee: AsyncParsableCommand {
        static var configuration = CommandConfiguration(
            abstract: "assignee"
        )

        @OptionGroup()
        var options: SwiftyJira.Options

        @Option(name: .long, help: "Key")
        var key: String

        @Option(name: .long, help: "Account ID")
        var accountId: String

        mutating func runAsync() async throws {
            let client = try options.jiraClient()
            if await client.auth() {
                await client.assignee(key: key, accountId: accountId)
            }
        }
    }
}
