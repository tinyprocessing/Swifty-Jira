import ArgumentParser
import SwiftyTextTable

extension JiraCLI.User {
    struct Information: AsyncParsableCommand {
        static var configuration = CommandConfiguration(
            abstract: "information"
        )

        @OptionGroup()
        var options: JiraCLI.Options

        mutating func runAsync() async throws {
            let client = try options.jiraClient()
            if await client.auth() {
                await client.user()
            }
        }
    }
}
