import ArgumentParser
import SwiftyTextTable

extension SwiftyJira.Issue {
    struct Create: AsyncParsableCommand {
        static var configuration = CommandConfiguration(
            abstract: "create"
        )

        @OptionGroup()
        var options: SwiftyJira.Options

        @Option(name: .long, help: "Parent Key")
        var parent: String

        @Option(name: .long, help: "Summary string")
        var summary: String

        @Option(name: .long, help: "Project ekey")
        var project: String

        @Option(name: .long, help: "Assignee ekey")
        var assignee: String

        mutating func runAsync() async throws {
            let client = try options.jiraClient()
            if await client.auth() {
                await client.create(parent: parent, summary: summary, project: project, assignee: assignee)
            }
        }
    }
}
