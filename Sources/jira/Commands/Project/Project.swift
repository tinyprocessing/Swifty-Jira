import ArgumentParser
import Foundation

extension SwiftyJira {
    struct Project: AsyncParsableCommand {
        static var configuration = CommandConfiguration(
            abstract: "all projects for user",
            subcommands: [View.self, List.self]
        )

        @OptionGroup()
        var options: SwiftyJira.Options

        mutating func runAsync() async throws {
            let command = try SwiftyJira.Project.parseAsRoot(["help"])
            try command.run()
        }
    }
}
