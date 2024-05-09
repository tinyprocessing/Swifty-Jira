import ArgumentParser
import SwiftyTextTable

extension SwiftyJira.User {
    struct Info: AsyncParsableCommand {
        static var configuration = CommandConfiguration(
            abstract: "info"
        )

        @OptionGroup()
        var options: SwiftyJira.Options

        mutating func runAsync() async throws {
            let client = try options.jiraClient()
            if await client.auth() {
                await client.user()
            }
        }
    }
}
