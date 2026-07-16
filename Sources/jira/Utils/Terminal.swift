import Foundation
#if canImport(Darwin)
import Darwin
#endif

/// Terminal helpers: width detection and ANSI-aware string measurement.
enum Terminal {
    /// Usable terminal width, in priority order:
    /// 1. COLUMNS env var (explicit override, also aids testing/piping),
    /// 2. ioctl TIOCGWINSZ when stdout is a TTY,
    /// 3. fallback 100 (e.g. piped output with no COLUMNS set).
    static var width: Int {
        if let cols = ProcessInfo.processInfo.environment["COLUMNS"],
           let n = Int(cols), n > 0 {
            return n
        }
        if isatty(STDOUT_FILENO) != 0 {
            #if canImport(Darwin)
            var w = winsize()
            if ioctl(STDOUT_FILENO, UInt(TIOCGWINSZ), &w) == 0, w.ws_col > 0 {
                return Int(w.ws_col)
            }
            #endif
        }
        return 100
    }

    /// Usable terminal height (rows). Falls back to 24.
    static var height: Int {
        if let lines = ProcessInfo.processInfo.environment["LINES"],
           let n = Int(lines), n > 0 {
            return n
        }
        if isatty(STDOUT_FILENO) != 0 {
            #if canImport(Darwin)
            var w = winsize()
            if ioctl(STDOUT_FILENO, UInt(TIOCGWINSZ), &w) == 0, w.ws_row > 0 {
                return Int(w.ws_row)
            }
            #endif
        }
        return 24
    }

    /// Length of a string ignoring ANSI escape sequences (\u{1B}[...m).
    static func visibleLength(_ s: String) -> Int {
        return stripANSI(s).count
    }

    static func stripANSI(_ s: String) -> String {
        var result = ""
        var iterator = s.unicodeScalars.makeIterator()
        var pending: [UnicodeScalar] = []
        var inEscape = false
        for scalar in s.unicodeScalars {
            if inEscape {
                // ANSI SGR ends with 'm'
                if scalar == "m" { inEscape = false }
                continue
            }
            if scalar == "\u{1B}" {
                inEscape = true
                continue
            }
            result.unicodeScalars.append(scalar)
        }
        _ = iterator
        _ = pending
        return result
    }

    /// Pad `s` to `width` columns counting only visible characters (ANSI-safe).
    /// Truncates (visible) if longer, appending an ellipsis.
    static func pad(_ s: String, to width: Int) -> String {
        let visible = stripANSI(s)
        if visible.count > width {
            // Truncate the plain string; drop color to keep truncation simple & correct.
            if width <= 1 { return String(visible.prefix(max(0, width))) }
            return String(visible.prefix(width - 1)) + "…"
        }
        let padding = String(repeating: " ", count: width - visible.count)
        return s + padding
    }
}
