import Foundation

struct CommandLineArgs {
    let command: String
    let parameters: [String]
}

func getCurrentDateString() -> String {
    let dateFormatter = DateFormatter()
    dateFormatter.dateFormat = "yyyy-MM-dd"
    let dateString = dateFormatter.string(from: Date())
    return dateString
}

func parseCommandLine() -> CommandLineArgs {
    let arguments = CommandLine.arguments
    guard arguments.count >= 2 else {
        return CommandLineArgs(command: "--help", parameters: [])
    }

    if arguments[1].hasPrefix("-") {
        return CommandLineArgs(command: arguments[1], parameters: Array(arguments.dropFirst(2)))
    } else {
        return CommandLineArgs(command: arguments[1], parameters: Array(arguments.dropFirst(2)))
    }
}
