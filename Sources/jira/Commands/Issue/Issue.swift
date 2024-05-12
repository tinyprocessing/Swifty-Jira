import ArgumentParser
import Foundation

extension SwiftyJira {
    struct Issue: AsyncParsableCommand {
        static var configuration = CommandConfiguration(
            abstract: "all issues for user",
            subcommands: [View.self, List.self, Transition.self]
        )

        @OptionGroup()
        var options: SwiftyJira.Options

        mutating func runAsync() async throws {}
    }
}
