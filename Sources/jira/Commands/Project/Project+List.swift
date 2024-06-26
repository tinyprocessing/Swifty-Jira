import ArgumentParser
import SwiftyTextTable

extension SwiftyJira.Project {
    struct List: AsyncParsableCommand {
        static var configuration = CommandConfiguration(
            abstract: "list"
        )

        @OptionGroup()
        var options: SwiftyJira.Options

        mutating func runAsync() async throws {
            let client = try options.jiraClient()
            if await client.auth() {
                await client.project()
            }
        }
    }
}
