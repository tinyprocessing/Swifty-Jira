import Foundation

/// Lightweight, ANSI-aware, terminal-width-aware table renderer.
/// Unlike SwiftyTextTable it measures visible (non-ANSI) length and caps the
/// total width to the terminal, giving the remaining space to flexible columns.
struct Table {
    struct Column {
        let header: String
        /// Fixed width. If nil, the column is flexible and shares leftover space.
        let fixedWidth: Int?
        init(_ header: String, width: Int? = nil) {
            self.header = header
            self.fixedWidth = width
        }
    }

    let title: String?
    let columns: [Column]
    private var rows: [[String]] = []

    init(title: String? = nil, columns: [Column]) {
        self.title = title
        self.columns = columns
    }

    mutating func addRow(_ values: [String]) {
        rows.append(values)
    }

    /// A visual separator row (empty cells).
    mutating func addSeparator() {
        rows.append(Array(repeating: "", count: columns.count))
    }

    func render() -> String {
        let widths = computeWidths()
        var lines: [String] = []

        let innerWidth = widths.reduce(0, +) + (3 * columns.count) - 1  // "| " + " | " chrome
        let border = "+" + String(repeating: "-", count: innerWidth) + "+"

        if let title = title {
            lines.append(border)
            lines.append("| " + Terminal.pad(title, to: innerWidth - 2) + " |")
        }
        lines.append(border)

        // Header
        lines.append(renderRow(columns.map { $0.header }, widths: widths))
        lines.append(border)

        // Rows
        for row in rows {
            lines.append(renderRow(row, widths: widths))
        }
        lines.append(border)

        return lines.joined(separator: "\n")
    }

    private func renderRow(_ values: [String], widths: [Int]) -> String {
        var cells: [String] = []
        for (i, width) in widths.enumerated() {
            let value = i < values.count ? values[i] : ""
            cells.append(Terminal.pad(value, to: width))
        }
        return "| " + cells.joined(separator: " | ") + " |"
    }

    private func computeWidths() -> [Int] {
        let total = Terminal.width
        // Chrome: leading "| ", trailing " |", and " | " between columns.
        let chrome = 2 + 2 + (columns.count - 1) * 3
        let available = max(20, total - chrome)

        // Natural width per column = max(header, content) visible length.
        var natural: [Int] = columns.map { Terminal.visibleLength($0.header) }
        for row in rows {
            for (i, cell) in row.enumerated() where i < natural.count {
                natural[i] = max(natural[i], Terminal.visibleLength(cell))
            }
        }

        // Fixed columns keep their configured (or natural) width.
        var widths = [Int](repeating: 0, count: columns.count)
        var flexibleIndices: [Int] = []
        var usedByFixed = 0
        for (i, col) in columns.enumerated() {
            if let fixed = col.fixedWidth {
                widths[i] = min(fixed, natural[i] > fixed ? fixed : max(fixed, natural[i]))
                widths[i] = fixed
                usedByFixed += widths[i]
            } else {
                flexibleIndices.append(i)
            }
        }

        let remaining = max(0, available - usedByFixed)
        if flexibleIndices.isEmpty {
            // No flexible columns: use natural widths for everything.
            return columns.enumerated().map { $0.element.fixedWidth ?? natural[$0.offset] }
        }

        // Distribute remaining space across flexible columns, capped at natural width.
        let share = remaining / flexibleIndices.count
        var leftover = remaining
        for idx in flexibleIndices {
            let w = min(natural[idx], share)
            widths[idx] = max(3, w)
            leftover -= widths[idx]
        }
        // Give any leftover to the widest flexible column (usually Summary).
        if leftover > 0, let widest = flexibleIndices.max(by: { natural[$0] < natural[$1] }) {
            widths[widest] += leftover
        }
        return widths
    }
}
