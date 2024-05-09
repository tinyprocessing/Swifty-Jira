import ArgumentParser
import SwiftyTextTable

extension JiraCLI.Project {
    struct List: AsyncParsableCommand {
        static var configuration = CommandConfiguration(
            abstract: "list"
        )

        @OptionGroup()
        var options: JiraCLI.Options

        mutating func runAsync() async throws {
            let client = try options.jiraClient()
            if await client.auth() {
                await client.project()
            }
        }
    }
}
