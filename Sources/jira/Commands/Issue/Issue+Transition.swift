import ArgumentParser
import SwiftyTextTable

extension SwiftyJira.Issue {
    struct Transition: AsyncParsableCommand {
        static var configuration = CommandConfiguration(
            abstract: "transition"
        )

        @OptionGroup()
        var options: SwiftyJira.Options

        @Option(name: .long, help: "Issue Key")
        var key: String

        @Option(name: .long, help: "Issue status")
        var status: String

        @Option(name: .long, default: "", help: "Issue resolution")
        var resolution: String

        mutating func runAsync() async throws {
            let client = try options.jiraClient()
            if await client.auth() {
                await client.transition(to: status, key: key, resolution: resolution)
            }
        }
    }
}
