import Foundation

/// Pure rendering for the interactive browser (no I/O beyond returning strings).
enum TUIView {
    static let reset = "\u{1B}[0m"
    static func fg(_ code: Int, _ s: String) -> String { "\u{1B}[\(code)m\(s)\(reset)" }
    static func bold(_ s: String) -> String { "\u{1B}[1m\(s)\(reset)" }
    static func invert(_ s: String) -> String { "\u{1B}[7m\(s)\(reset)" }
    static func dim(_ s: String) -> String { "\u{1B}[2m\(s)\(reset)" }

    static func clear() -> String { "\u{1B}[2J\u{1B}[H" }
    static func moveTo(_ row: Int, _ col: Int) -> String { "\u{1B}[\(row);\(col)H" }

    /// Colour for a status name.
    static func statusColor(_ status: String) -> Int {
        let s = status.lowercased()
        if s.contains("done") || s.contains("closed") || s.contains("complete") { return 32 } // green
        if s.contains("progress") || s.contains("review") { return 33 } // yellow
        if s.contains("blocked") { return 31 } // red
        return 36 // cyan
    }

    static func typeBadge(_ type: String) -> String {
        switch type {
        case "Sub-task": return fg(37, "ST")
        case "Task": return fg(34, "T ")
        case "Bug": return fg(31, "B ")
        case "Story": return fg(33, "S ")
        default: return "? "
        }
    }

    /// Render the list screen. Returns the full frame as a string.
    static func renderList(
        title: String,
        issues: [Issue],
        selected: Int,
        scrollOffset: Int,
        filterInput: String?,
        message: String?,
        countLabel: String? = nil,
        hasMore: Bool = false
    ) -> String {
        let width = Terminal.width
        let height = Terminal.height
        var out = clear()

        // Header bar
        let count = countLabel ?? "\(issues.count) issues"
        let header = " swifty-jira  •  \(title)  •  \(count) "
        out += invert(bold(Terminal.pad(header, to: width))) + "\n"

        // Body rows. Each issue may occupy up to two lines: a long summary wraps
        // onto a second, indented line so the created date and status stay visible.
        let bodyHeight = max(3, height - 4) // header + footer + filter line

        let keyW = 12, dateW = 10, statusW = 14
        // leading space + badge(2) + space + key + space + [summary] + space + date + space + status
        let indent = 1 + 2 + 1 + keyW + 1
        let summaryWidth = summaryWidth(forTerminalWidth: width)

        var rows: [String] = []
        build: for (idx, issue) in issues.enumerated().dropFirst(scrollOffset) {
            let f = issue.fields
            let key = issue.key ?? "?"
            let type = typeBadge(f?.issuetype?.name ?? "")
            let status = f?.status?.name ?? ""
            let statusStr = fg(statusColor(status), status)
            let created = f?.created?.components(separatedBy: "T").first ?? ""
            let summary = (f?.summary ?? "").replacingOccurrences(of: "\n", with: " ")

            let keyPad = Terminal.pad(key, to: keyW)
            let datePad = Terminal.pad(created, to: dateW)
            let statusPad = padVisible(statusStr, to: statusW)

            // Wrap the summary but cap at two lines so the list stays dense.
            let chunks = Array(wrapPlain(summary, width: summaryWidth).prefix(2))
            for (ci, chunk) in chunks.enumerated() {
                if rows.count >= bodyHeight { break build }
                var line: String
                if ci == 0 {
                    let summaryPad = Terminal.pad(chunk, to: summaryWidth)
                    line = " \(type) \(keyPad) \(summaryPad) \(datePad) \(statusPad)"
                } else {
                    let summaryPad = Terminal.pad(chunk, to: summaryWidth)
                    line = String(repeating: " ", count: indent) + summaryPad
                }
                if idx == selected {
                    line = invert(Terminal.pad(stripToWidth(line, width), to: width))
                } else {
                    line = Terminal.pad(line, to: width)
                }
                rows.append(line)
            }
        }

        for row in rows { out += row + "\n" }
        // Fill remaining body rows
        for _ in rows.count..<bodyHeight {
            out += "\n"
        }

        // Filter line
        if let filterInput = filterInput {
            out += invert(Terminal.pad(" search (local text): \(filterInput)_", to: width)) + "\n"
        } else if let message = message {
            out += dim(Terminal.pad(" \(message)", to: width)) + "\n"
        } else {
            out += "\n"
        }

        // Footer with key hints
        let loadMore = hasMore ? "  L load more  " : ""
        let hints = " j/k  enter  e edit  f views  / search  o open  y copy  r refresh\(loadMore)  q quit "
        out += invert(Terminal.pad(hints, to: width))
        return out
    }

    /// Overlay shown when user presses q — waits for confirmation.
    static func renderQuitConfirm(over base: String) -> String {
        let width = Terminal.width
        // Re-render the base screen then overlay a centered prompt.
        var out = base
        let msg = "  Quit swifty-jira? Press q again (or y) to exit, any other key to stay.  "
        let padded = Terminal.pad(msg, to: width)
        out += "\n" + invert(bold(fg(31, padded)))
        return out
    }

    /// Render the detail screen for one issue.
    static func renderDetail(_ issue: Issue, domain: String, status: String? = nil) -> String {
        let width = Terminal.width
        var out = clear()
        let f = issue.fields
        let key = issue.key ?? "?"

        out += invert(bold(Terminal.pad(" \(key)  •  \(f?.issuetype?.name ?? "")  •  \(f?.status?.name ?? "")", to: width))) + "\n\n"

        func field(_ label: String, _ value: String?) -> String {
            guard let value = value, !value.isEmpty else { return "" }
            return bold(fg(36, "\(label): ")) + value + "\n"
        }

        out += field("Summary", f?.summary)
        out += field("Assignee", f?.assignee?.displayName)
        out += field("Reporter", f?.reporter?.displayName)
        out += field("Priority", f?.priority?.name)
        out += field("Created", f?.created?.components(separatedBy: "T").first)
        out += field("Updated", f?.updated?.components(separatedBy: "T").first)
        if let parent = f?.parent?.key {
            out += field("Parent", "\(parent) — \(f?.parent?.fields?.summary ?? "")")
        }
        out += "\n"

        if let desc = f?.description, !desc.isEmpty {
            out += bold(fg(36, "Description:")) + "\n"
            let cleaned = desc.replacingOccurrences(of: "\r", with: "")
            for line in cleaned.split(separator: "\n", omittingEmptySubsequences: false) {
                for chunk in wrapPlain(String(line), width: width - 2) {
                    out += "  \(chunk)\n"
                }
            }
            out += "\n"
        }

        if let subs = f?.subtasks, !subs.isEmpty {
            out += bold(fg(36, "Subtasks (\(subs.count)):")) + "\n"
            for st in subs {
                out += "  • \(st.key ?? "") — \(st.fields?.summary ?? "") [\(st.fields?.status?.name ?? "")]\n"
            }
            out += "\n"
        }

        if let links = f?.issuelinks, !links.isEmpty {
            out += bold(fg(36, "Linked:")) + "\n"
            for link in links {
                if let o = link.outwardIssue {
                    out += "  \(link.type?.outward ?? "→") \(o.key ?? "") — \(o.fields?.summary ?? "")\n"
                }
                if let i = link.inwardIssue {
                    out += "  \(link.type?.inward ?? "←") \(i.key ?? "") — \(i.fields?.summary ?? "")\n"
                }
            }
            out += "\n"
        }

        if let comments = f?.comment?.comments, !comments.isEmpty {
            out += bold(fg(36, "Comments (\(comments.count)):")) + "\n"
            for c in comments.suffix(5) {
                let who = c.author?.displayName ?? "?"
                let when = c.created?.components(separatedBy: "T").first ?? ""
                out += dim("  \(who) · \(when)") + "\n"
                for chunk in wrapPlain((c.body ?? "").replacingOccurrences(of: "\r\n", with: " "), width: width - 4) {
                    out += "    \(chunk)\n"
                }
            }
        }

        // Bound the body to the screen height so the header never scrolls off.
        // Reserve rows for the footer bar (+ optional status line).
        let reserved = status != nil ? 2 : 1
        let maxBodyRows = max(3, Terminal.height - reserved)
        var bodyLines = out.components(separatedBy: "\n")
        if bodyLines.count > maxBodyRows {
            bodyLines = Array(bodyLines.prefix(maxBodyRows - 1))
            bodyLines.append(dim("  … (truncated — press o to open full issue in browser)"))
        }
        out = bodyLines.joined(separator: "\n")

        if let status = status {
            out += "\n" + fg(32, Terminal.pad(" ✓ \(status)", to: width))
        }
        out += "\n" + invert(Terminal.pad(" esc/q back   e edit   o open   y copy link ", to: width))
        return out
    }

    /// Render the transition picker overlay for the `e` (edit) action.
    static func renderTransitionPicker(key: String, transitions: [TransitionElement], selected: Int) -> String {
        let width = Terminal.width
        let height = Terminal.height
        var out = clear()

        out += invert(bold(Terminal.pad(" Move \(key) to…", to: width))) + "\n\n"

        let bodyHeight = max(3, height - 4)
        for (idx, t) in transitions.enumerated().prefix(bodyHeight) {
            let name = t.name ?? "?"
            let to = t.to?.name.map { " → \($0)" } ?? ""
            var line = "   \(name)\(to)"
            if idx == selected {
                line = invert(Terminal.pad(stripToWidth(line, width), to: width))
            } else {
                line = Terminal.pad(line, to: width)
            }
            out += line + "\n"
        }

        let shown = min(transitions.count, bodyHeight)
        for _ in shown..<bodyHeight { out += "\n" }

        out += "\n" + invert(Terminal.pad(" j/k move   enter apply   esc/q cancel ", to: width))
        return out
    }

    /// Render the view picker (`f`). Each row: name, explanation, resolved JQL.
    static func renderViewPicker(
        views: [(name: String, about: String, jql: String)],
        selected: Int,
        activeName: String,
        note: String?
    ) -> String {
        let width = Terminal.width
        let height = Terminal.height
        var out = clear()

        out += invert(bold(Terminal.pad(" Views — choose what to see", to: width))) + "\n\n"

        // Two lines per view: a name row and an indented JQL/about row.
        var rows: [String] = []
        for (idx, view) in views.enumerated() {
            let active = view.name == activeName ? fg(32, " ●") : "  "
            let head = "\(active) \(bold(view.name))" + (view.about.isEmpty ? "" : dim("  — \(view.about)"))
            let jql = dim("      \(view.jql)")

            var line1 = Terminal.pad(head, to: width)
            let line2 = Terminal.pad(jql, to: width)
            if idx == selected {
                line1 = invert(Terminal.pad(stripToWidth(head, width), to: width))
            }
            rows.append(line1)
            rows.append(line2)
        }

        let bodyHeight = max(3, height - 4)
        if rows.count > bodyHeight { rows = Array(rows.prefix(bodyHeight)) }
        for row in rows { out += row + "\n" }
        for _ in rows.count..<bodyHeight { out += "\n" }

        if let note = note {
            out += dim(Terminal.pad("  \(note)", to: width)) + "\n"
        } else {
            out += "\n"
        }
        out += invert(Terminal.pad(" j/k move   enter apply   n new   x delete   esc/q cancel ", to: width))
        return out
    }

    /// The kind of input a field uses in the editor.
    enum EditKind {
        case singleLine, multiLine, transition, json
    }

    /// Render the field-editor menu for the `e` action.
    static func renderEditMenu(
        key: String,
        fields: [(label: String, value: String, kind: EditKind)],
        selected: Int,
        note: String?
    ) -> String {
        let width = Terminal.width
        let height = Terminal.height
        var out = clear()

        out += invert(bold(Terminal.pad(" Edit \(key)", to: width))) + "\n\n"

        let labelW = 26
        for (idx, field) in fields.enumerated() {
            let marker: String
            switch field.kind {
            case .transition: marker = "⇄"
            case .multiLine:  marker = "¶"
            case .json:       marker = "{}"
            case .singleLine: marker = " "
            }
            let label = Terminal.pad("\(marker) \(field.label)", to: labelW)
            // Single-line preview of the current value.
            let preview = field.value
                .replacingOccurrences(of: "\n", with: "↵ ")
                .trimmingCharacters(in: .whitespaces)
            let valueW = max(10, width - labelW - 4)
            let shown = preview.isEmpty ? dim("—") : Terminal.pad(preview, to: valueW)

            var line = "  \(label)  \(shown)"
            if idx == selected {
                line = invert(Terminal.pad(stripToWidth(line, width), to: width))
            } else {
                line = Terminal.pad(line, to: width)
            }
            out += line + "\n"
        }

        // Fill down to just above the footer.
        let usedRows = 2 + fields.count
        let footerRows = note != nil ? 3 : 2
        let fill = max(0, height - usedRows - footerRows)
        for _ in 0..<fill { out += "\n" }

        if let note = note {
            out += dim(Terminal.pad("  \(note)", to: width)) + "\n"
        }
        out += "\n" + invert(Terminal.pad(" j/k move   enter edit field   esc/q back (saved on edit) ", to: width))
        return out
    }

    /// Render the single/multi-line text editor.
    static func renderTextEditor(title: String, text: String, multiline: Bool) -> String {
        let width = Terminal.width
        let height = Terminal.height
        var out = clear()

        out += invert(bold(Terminal.pad(" \(title)", to: width))) + "\n\n"

        let bodyHeight = max(3, height - 4)
        // Wrap the current text; show a cursor block at the end.
        let withCursor = text + "▏"
        var rendered: [String] = []
        for rawLine in withCursor.components(separatedBy: "\n") {
            let chunks = wrapPlain(rawLine, width: width - 2)
            rendered.append(contentsOf: chunks.isEmpty ? [""] : chunks)
        }
        // Keep the tail visible (where the cursor is) if the text overflows.
        if rendered.count > bodyHeight {
            rendered = Array(rendered.suffix(bodyHeight))
        }
        for line in rendered { out += "  " + Terminal.pad(line, to: width - 2) + "\n" }
        for _ in rendered.count..<bodyHeight { out += "\n" }

        let hints = multiline
            ? " type to edit   enter newline   ⌃S save   ⌃U clear   esc cancel "
            : " type to edit   enter save   ⌃U clear   esc cancel "
        out += invert(Terminal.pad(hints, to: width))
        return out
    }

    // MARK: - layout helpers (shared with TUIApp scroll math)

    /// Width of the flexible summary column for a given terminal width.
    /// Must match the column layout used in `renderList`.
    static func summaryWidth(forTerminalWidth width: Int) -> Int {
        let keyW = 12, dateW = 10, statusW = 14
        let indent = 1 + 2 + 1 + keyW + 1
        let used = indent + 1 + dateW + 1 + statusW
        return max(10, width - used)
    }

    /// Number of screen lines an issue occupies in the list (capped at 2, to
    /// match the summary-wrap cap in `renderList`).
    static func rowHeight(_ issue: Issue, terminalWidth width: Int) -> Int {
        let summary = (issue.fields?.summary ?? "").replacingOccurrences(of: "\n", with: " ")
        let chunks = wrapPlain(summary, width: summaryWidth(forTerminalWidth: width))
        return min(2, max(1, chunks.count))
    }

    // MARK: - helpers

    /// Pad a string that may contain ANSI codes to a visible width.
    private static func padVisible(_ s: String, to width: Int) -> String {
        Terminal.pad(s, to: width)
    }

    private static func stripToWidth(_ s: String, _ width: Int) -> String {
        let plain = Terminal.stripANSI(s)
        if plain.count > width { return String(plain.prefix(width)) }
        return plain
    }

    private static func wrapPlain(_ text: String, width: Int) -> [String] {
        guard width > 4 else { return [text] }
        guard !text.isEmpty else { return [""] }
        var lines: [String] = []
        var current = ""
        for word in text.split(separator: " ") {
            let w = String(word)
            if current.isEmpty { current = w }
            else if current.count + 1 + w.count <= width { current += " " + w }
            else { lines.append(current); current = w }
            while current.count > width {
                lines.append(String(current.prefix(width)))
                current = String(current.dropFirst(width))
            }
        }
        if !current.isEmpty { lines.append(current) }
        return lines
    }
}
