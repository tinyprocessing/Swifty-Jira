import ArgumentParser
import SwiftyTextTable

extension SwiftyJira.Project {
    struct View: AsyncParsableCommand {
        static var configuration = CommandConfiguration(
            abstract: "view"
        )

        @OptionGroup()
        var options: SwiftyJira.Options

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
