import ArgumentParser
import Foundation

extension SwiftyJira {
    /// Interactive keyboard-driven Jira browser (k9s-style).
    struct Browse: AsyncParsableCommand {
        static var configuration = CommandConfiguration(
            abstract: "Interactive TUI to browse your issues (↑/↓ navigate, enter for details, / to filter, q to quit)"
        )

        @OptionGroup()
        var options: SwiftyJira.Options

        @Option(name: .long, default: "openSprints", help: "Preset filter: openSprints | undone | all | openAndFutureSprints | backlog | <status>")
        var filter: String

        @Option(name: .long, default: nil, help: "Custom JQL (overrides --filter)")
        var jql: String?

        mutating func runAsync() async throws {
            let client = try options.jiraClient()
            // Authenticate BEFORE entering raw mode: a WebKit SSO window mid-TUI
            // would corrupt the alternate screen. auth() reuses the cached cookie.
            guard await client.auth() else {
                fputs("Authentication required. Run `swifty-jira user info` to log in.\n", stderr)
                Foundation.exit(2)
            }
            let app = TUIApp(client: client, domain: options.url, filter: filter, customJQL: jql)
            await app.run()
        }
    }
}
