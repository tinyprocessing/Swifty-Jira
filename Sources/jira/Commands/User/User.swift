import ArgumentParser
import Foundation

extension SwiftyJira {
    struct User: AsyncParsableCommand {
        static var configuration = CommandConfiguration(
            abstract: "information about current user",
            subcommands: [Info.self]
        )

        mutating func runAsync() async throws {
            let command = try SwiftyJira.User.parseAsRoot(["help"])
            try command.run()
        }
    }
}
