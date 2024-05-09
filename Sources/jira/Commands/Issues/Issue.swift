import ArgumentParser
import Foundation

extension JiraCLI {
    struct Issue: AsyncParsableCommand {
        static var configuration = CommandConfiguration(
            abstract: "all issues for user",
            subcommands: [List.self]
        )

        @OptionGroup()
        var options: JiraCLI.Options

        @Option(name: .long, help: "Issue Key")
        var key: String

        mutating func runAsync() async throws {
            let client = try options.jiraClient()
            if await client.auth() {
                await client.issue(id: key)
            }
        }
    }
}
