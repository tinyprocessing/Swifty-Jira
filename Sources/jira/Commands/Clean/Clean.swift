import ArgumentParser
import Foundation

extension SwiftyJira {
    struct Clean: AsyncParsableCommand {
        static var configuration = CommandConfiguration(
            abstract: "clean local auth method"
        )

        @OptionGroup()
        var options: SwiftyJira.Options

        mutating func runAsync() async throws {
            let manager: CookieManager = CookieManager()
            manager.saveCookies([])
            manager.clean()
        }
    }
}
