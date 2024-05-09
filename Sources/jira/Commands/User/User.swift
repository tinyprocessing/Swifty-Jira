import ArgumentParser
import Foundation

extension SwiftyJira {
    struct User: AsyncParsableCommand {
        mutating func runAsync() async throws {}

        static var configuration = CommandConfiguration(
            abstract: "information about current user",
            subcommands: [Info.self]
        )
    }
}
