import Foundation

/// Generic interactive picker: shows a filterable list, returns selected item.
/// Used for Sprint, Epic, and User pickers.
struct TUIPicker {
    struct Item {
        let label: String       // shown in list (main line)
        let sublabel: String    // shown dimmed below label (e.g. login / sprint state)
        let value: String       // what gets returned / applied
    }

    let title: String
    let hint: String            // shown in footer (e.g. "type to filter, enter to pick")
    let searchPrompt: String    // e.g. "filter:" or "search (Enter to query Jira):"
    let searchOnEnter: Bool     // true → hitting Enter triggers external search (users)
}

// MARK: - Render

extension TUIPicker {
    func render(items: [Item], selected: Int, query: String, message: String?, typing: Bool = false) -> String {
        let width = Terminal.width
        let height = Terminal.height
        var out = TUIView.clear()

        // Header
        out += TUIView.invert(TUIView.bold(Terminal.pad(" \(title) ", to: width))) + "\n"

        // Body
        let bodyH = max(3, height - 4)
        let start = max(0, selected - bodyH + 2)
        let slice = Array(items.enumerated()).dropFirst(start).prefix(bodyH)

        for (idx, item) in slice {
            let labelW = max(20, width - 4)
            var line: String
            if item.sublabel.isEmpty {
                line = "  " + Terminal.pad(item.label, to: labelW)
            } else {
                let labelPart = Terminal.pad(item.label, to: labelW - 18)
                let subPart = TUIView.dim(Terminal.pad(item.sublabel, to: 16))
                line = "  " + labelPart + "  " + subPart
            }
            if idx == selected {
                line = TUIView.invert(Terminal.pad(Terminal.stripANSI(line), to: width))
            } else {
                line = Terminal.pad(line, to: width)
            }
            out += line + "\n"
        }
        for _ in slice.count..<bodyH { out += "\n" }

        // Status / search line
        let searchLabel = searchOnEnter ? " \(searchPrompt) \(query)_ (press Enter to search)" : " \(searchPrompt) \(query)_"
        if let msg = message {
            out += TUIView.dim(Terminal.pad(" \(msg)", to: width)) + "\n"
        } else {
            out += TUIView.invert(Terminal.pad(searchLabel, to: width)) + "\n"
        }

        // Footer — when typing, j/k write chars not navigate
        let navHint = typing ? " ↑/↓ navigate   j/k type   " : " ↑/↓  j/k navigate   "
        out += TUIView.invert(Terminal.pad("\(navHint)Enter pick   Esc cancel   \(hint) ", to: width))
        return out
    }
}

// MARK: - Interaction

extension TUIPicker {
    /// Run the picker loop. Returns the selected Item's value, or nil if cancelled.
    /// `searcher` is called when searchOnEnter=true and user presses Enter with a
    /// non-empty query (asynchronously returns new items to show).
    func run(
        term: RawTerminal,
        initial: [Item],
        searcher: ((String) async -> [Item])? = nil
    ) async -> String? {
        var items = initial
        var selected = 0
        var query = ""
        var message: String? = nil

        func draw(_ msg: String? = nil) {
            let frame = render(items: items, selected: selected, query: query, message: msg ?? message, typing: !query.isEmpty)
            FileHandle.standardOutput.write(frame.data(using: .utf8)!)
        }

        draw()

        while true {
            let key = term.readKey()
            switch key {
            case .escape, .char("q") where query.isEmpty:
                return nil

            // j/k navigate ONLY when query is empty — otherwise they type into query.
            case .up, .char("k") where query.isEmpty:
                selected = max(0, selected - 1); draw()

            case .down, .char("j") where query.isEmpty:
                selected = min(max(0, items.count - 1), selected + 1); draw()

            // Arrow keys always navigate (don't type).
            case .up:
                selected = max(0, selected - 1); draw()

            case .down:
                selected = min(max(0, items.count - 1), selected + 1); draw()

            case .enter:
                if searchOnEnter {
                    if !query.isEmpty {
                        message = "Searching…"; draw()
                        if let searcher = searcher {
                            items = await searcher(query)
                            selected = 0
                            message = nil
                            draw()
                        }
                    } else {
                        // No query typed yet — pick selected item only if it has
                        // a real value (not a placeholder/hint item).
                        if items.indices.contains(selected) {
                            let v = items[selected].value
                            if !v.isEmpty { return v }
                        }
                        // Otherwise hint the user.
                        message = "Type a name above, then press Enter to search."
                        draw()
                    }
                } else {
                    guard items.indices.contains(selected) else { continue }
                    let v = items[selected].value
                    if !v.isEmpty { return v }
                }

            case .char(let c) where c == "\u{7F}" || c == "\u{08}":
                if !query.isEmpty {
                    query.removeLast()
                    if !searchOnEnter {
                        items = filterItems(initial, query: query)
                        selected = 0
                    }
                    draw()
                }

            case .char(let c):
                query.append(c)
                if !searchOnEnter {
                    items = filterItems(initial, query: query)
                    selected = 0
                }
                draw()

            default:
                break
            }
        }
    }

    private func filterItems(_ all: [Item], query: String) -> [Item] {
        guard !query.isEmpty else { return all }
        let q = query.lowercased()
        return all.filter {
            $0.label.lowercased().contains(q) || $0.sublabel.lowercased().contains(q)
        }
    }
}
