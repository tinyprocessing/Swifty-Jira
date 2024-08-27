import ArgumentParser
import SwiftyTextTable

extension SwiftyJira.Issue {
    struct View: AsyncParsableCommand {
        static var configuration = CommandConfiguration(
            abstract: "view"
        )

        @OptionGroup()
        var options: SwiftyJira.Options

        @Option(name: .long, help: "Issue Key")
        var key: String

        @Option(name: .long, default: false, help: "View in browser")
        var viewInWeb: Bool

        mutating func runAsync() async throws {
            let client = try options.jiraClient()
            if viewInWeb {
                await client.issue(id: key, viewInWeb: viewInWeb)
                return
            }
            if await client.auth() {
                await client.issue(id: key, viewInWeb: viewInWeb)
            }
        }
    }
}
