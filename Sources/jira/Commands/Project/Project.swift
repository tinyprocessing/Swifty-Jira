import ArgumentParser
import Foundation

extension JiraCLI {
    struct Project: AsyncParsableCommand {
        static var configuration = CommandConfiguration(
            abstract: "all projects for user",
            subcommands: [List.self]
        )

        @OptionGroup()
        var options: JiraCLI.Options

        @Option(name: .long, help: "Project Key ")
        var key: String

        mutating func runAsync() async throws {
            let client = try options.jiraClient()
            if await client.auth() {
                await client.project(key: key)
            }
        }
    }
}
