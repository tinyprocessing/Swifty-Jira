import ArgumentParser
import Foundation

extension SwiftyJira {
    /// One-shot JSON snapshot for AI agents: who am I, active sprint, my open issues.
    struct Context: AsyncParsableCommand {
        static var configuration = CommandConfiguration(
            abstract: "Print a JSON snapshot (user + active sprint + my open issues) for AI agents"
        )

        @OptionGroup()
        var options: SwiftyJira.Options

        @Option(name: .long, default: nil, help: "Project key to resolve the active sprint, e.g. MEM")
        var project: String?

        mutating func runAsync() async throws {
            let client = try options.jiraClient()
            if await client.auth() {
                await client.exportContext(projectKey: project)
            }
        }
    }
}
