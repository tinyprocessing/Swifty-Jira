import Foundation
#if canImport(Darwin)
import Darwin
#endif

/// Puts the terminal into raw mode + alternate screen for a TUI session and
/// GUARANTEES restoration on every exit path (normal, throw, or SIGINT/SIGTERM).
final class RawTerminal {
    private var original = termios()
    private var active = false

    /// Global reference so the C signal handler can restore state.
    static weak var shared: RawTerminal?

    init() {
        RawTerminal.shared = self
    }

    /// Enter raw mode + alt screen + hide cursor. Returns false if not a TTY.
    @discardableResult
    func enter() -> Bool {
        guard isatty(STDIN_FILENO) != 0, isatty(STDOUT_FILENO) != 0 else {
            return false
        }
        tcgetattr(STDIN_FILENO, &original)
        var raw = original
        // Disable canonical mode + echo; keep signals (ISIG) so Ctrl-C still fires.
        raw.c_lflag &= ~(UInt(ICANON) | UInt(ECHO))
        raw.c_iflag &= ~(UInt(IXON) | UInt(ICRNL))
        // VMIN=1, VTIME=0 → blocking read of at least one byte.
        // c_cc is a fixed-size tuple; VMIN/VTIME indices are 16/17 on macOS.
        withUnsafeMutablePointer(to: &raw.c_cc) { ptr in
            ptr.withMemoryRebound(to: cc_t.self, capacity: Int(NCCS)) { cc in
                cc[Int(VMIN)] = 1
                cc[Int(VTIME)] = 0
            }
        }
        tcsetattr(STDIN_FILENO, TCSAFLUSH, &raw)
        active = true

        installSignalHandlers()
        write("\u{1B}[?1049h")  // alt screen
        write("\u{1B}[?25l")    // hide cursor
        return true
    }

    /// Restore everything. Idempotent — safe to call multiple times.
    func exit() {
        guard active else { return }
        active = false
        write("\u{1B}[?25h")    // show cursor
        write("\u{1B}[?1049l")  // leave alt screen
        tcsetattr(STDIN_FILENO, TCSAFLUSH, &original)
    }

    deinit {
        exit()
    }

    private func write(_ s: String) {
        FileHandle.standardOutput.write(s.data(using: .utf8)!)
    }

    private func installSignalHandlers() {
        let handler: @convention(c) (Int32) -> Void = { _ in
            RawTerminal.shared?.exit()
            // Re-raise default behaviour so the process actually terminates.
            Foundation.exit(130)
        }
        signal(SIGINT, handler)
        signal(SIGTERM, handler)
    }
}

/// A single decoded key press.
enum Key: Equatable {
    case up, down, left, right
    case enter
    case escape
    case char(Character)
    case unknown
}

extension RawTerminal {
    /// Blocking read of the next key (decodes arrow escape sequences).
    func readKey() -> Key {
        var byte: UInt8 = 0
        let n = read(STDIN_FILENO, &byte, 1)
        guard n == 1 else { return .unknown }

        if byte == 0x1B {  // ESC — could be arrow key or bare escape
            // Bytes after ESC arrive together for arrow keys. A lone ESC sends
            // nothing more, so read the follow-up bytes with a short timeout
            // (poll) instead of a blocking read — otherwise bare ESC hangs.
            guard let b1 = readByteWithTimeout(ms: 50) else { return .escape }
            guard let b2 = readByteWithTimeout(ms: 50) else { return .escape }
            if b1 == 0x5B {  // '['
                switch b2 {
                case 0x41: return .up
                case 0x42: return .down
                case 0x43: return .right
                case 0x44: return .left
                default: return .unknown
                }
            }
            return .escape
        }
        if byte == 0x0A || byte == 0x0D { return .enter }
        return .char(Character(UnicodeScalar(byte)))
    }

    /// Reads one byte, waiting up to `ms` milliseconds. Returns nil on timeout.
    private func readByteWithTimeout(ms: Int32) -> UInt8? {
        var fds = pollfd(fd: STDIN_FILENO, events: Int16(POLLIN), revents: 0)
        let ready = poll(&fds, 1, ms)
        guard ready > 0, (fds.revents & Int16(POLLIN)) != 0 else { return nil }
        var byte: UInt8 = 0
        let n = read(STDIN_FILENO, &byte, 1)
        return n == 1 ? byte : nil
    }
}
