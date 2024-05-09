import ArgumentParser
import Foundation

@available(macOS 12.0, *)
protocol AsyncParsableCommand: ParsableCommand {
    mutating func runAsync() async throws
}

extension ParsableCommand {
    static func start(_ arguments: [String]? = nil) async {
        do {
            let command = try parseAsRoot(arguments)
            if #available(macOS 12.0, *), var asyncCommand = command as? AsyncParsableCommand {
                try await asyncCommand.runAsync()
            } else {
                try command.run()
            }
        } catch {
            exit(withError: error)
        }
    }
}

struct JiraCLI: AsyncParsableCommand {
    static var configuration = CommandConfiguration(
        abstract: "A jira command line interface",
        subcommands: [User.self, Project.self, Issue.self]
    )

    struct Options: ParsableArguments {
        @Option(name: .long, default: ProcessInfo.processInfo.environment["JIRA_URL"], help: "Jira URL, for example: https://your_jira_url.com")
        var url: String

        func jiraClient() throws -> Jira {
            return Jira(domain: url)
        }
    }

    mutating func runAsync() async throws {}
}
