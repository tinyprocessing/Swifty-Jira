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

struct SwiftyJira: AsyncParsableCommand {
    static var configuration = CommandConfiguration(
        abstract: "A Jira command line client with SSO auth.",
        discussion: """
        Human output is rendered as terminal tables; add --enable-json (where \
        available) or use `issue export` / `context` for machine-readable JSON \
        on stdout. All logs/errors go to stderr.

        For AI agents: run `swifty-jira guide` for a full, self-contained usage \
        reference, and set SWIFTY_JIRA_NONINTERACTIVE=1 so auth fails fast \
        instead of opening an SSO browser window.

        Set the Jira server via the JIRA_URL env var or --url.
        """,
        subcommands: [User.self, Project.self, Issue.self, Browse.self, Context.self, Guide.self, Clean.self]
    )

    struct Options: ParsableArguments {
        @Option(
            name: .long,
            default: ProcessInfo.processInfo.environment["JIRA_URL"],
            help: "Jira URL, for example: https://your_jira_url.com"
        )
        var url: String

        func jiraClient() throws -> Jira {
            return Jira(domain: url)
        }
    }

    mutating func runAsync() async throws {
        let command = try SwiftyJira.parseAsRoot(["help"])
        try command.run()
    }
}
