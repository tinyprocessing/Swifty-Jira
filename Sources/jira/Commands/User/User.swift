import ArgumentParser
import Foundation

extension JiraCLI {
    struct User: AsyncParsableCommand {
        mutating func runAsync() async throws {}

        static var configuration = CommandConfiguration(
            abstract: "information about current user",
            subcommands: [Information.self]
        )
    }
}
