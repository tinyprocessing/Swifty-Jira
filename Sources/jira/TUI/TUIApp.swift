import AppKit
import Foundation

/// Interactive keyboard-driven Jira browser (k9s-style).
final class TUIApp {
    private let client: Jira
    private let domain: String
    private var filter: String
    private var customJQL: String?

    /// Presets cycled by the `f` key. `backlog` is omitted because its JQL is
    /// project-specific (MEM-only); use `--filter backlog` at launch for that.
    private static let presets = ["openSprints", "undone", "all", "openAndFutureSprints"]

    private var allIssues: [Issue] = []
    private var filtered: [Issue] = []
    /// Active local text search; persisted so a refresh keeps the same view.
    private var textFilter = ""
    private var selected = 0
    private var scrollOffset = 0
    private var message: String?

    private let term = RawTerminal()

    init(client: Jira, domain: String, filter: String, customJQL: String?) {
        self.client = client
        self.domain = domain
        self.filter = filter
        self.customJQL = customJQL
    }

    func run() async {
        guard term.enter() else {
            fputs("Interactive mode requires a real terminal (TTY).\n", stderr)
            return
        }
        defer { term.exit() }

        await reload()
        drawList()

        loop: while true {
            let key = term.readKey()
            switch key {
            case .char("q"), .escape:
                break loop
            case .up, .char("k"):
                moveSelection(-1)
            case .down, .char("j"):
                moveSelection(1)
            case .char("g"):
                selected = 0; scrollOffset = 0; drawList()
            case .char("G"):
                selected = max(0, filtered.count - 1); adjustScroll(); drawList()
            case .enter:
                await showDetail()
            case .char("/"):
                await runFilterPrompt()
            case .char("f"):
                await cyclePreset()
            case .char("o"):
                openInBrowser()
            case .char("y"):
                copyLink()
            case .char("e"):
                await editStatus()
            case .char("r"):
                message = "Refreshing…"; drawList()
                await reload(); drawList()
            default:
                break
            }
        }
    }

    // MARK: - Data

    /// Advance to the next server-side preset filter (clears any custom JQL and
    /// any active text search, then re-fetches).
    private func cyclePreset() async {
        customJQL = nil
        textFilter = ""
        let currentIndex = TUIApp.presets.firstIndex(of: filter) ?? -1
        filter = TUIApp.presets[(currentIndex + 1) % TUIApp.presets.count]
        message = "Filter: \(filter) — loading…"
        drawList()
        await reload()
        drawList()
    }

    private func reload() async {
        if let response = await client.fetchIssues(filter: filter, customJQL: customJQL) {
            allIssues = response.issues ?? []
            // Re-apply any active text search so a refresh keeps the same view.
            applyTextFilter(textFilter, resetSelection: false)
            message = nil
        } else {
            message = "Failed to load issues (session may be stale — run `swifty-jira user info`)."
        }
        selected = min(selected, max(0, filtered.count - 1))
        adjustScroll()
    }

    private func applyTextFilter(_ text: String, resetSelection: Bool = true) {
        textFilter = text
        if text.isEmpty {
            filtered = allIssues
        } else {
            let q = text.lowercased()
            filtered = allIssues.filter {
                ($0.key ?? "").lowercased().contains(q) ||
                ($0.fields?.summary ?? "").lowercased().contains(q) ||
                ($0.fields?.status?.name ?? "").lowercased().contains(q)
            }
        }
        if resetSelection {
            selected = 0
            scrollOffset = 0
        }
    }

    // MARK: - Navigation

    private func moveSelection(_ delta: Int) {
        guard !filtered.isEmpty else { return }
        selected = max(0, min(filtered.count - 1, selected + delta))
        adjustScroll()
        drawList()
    }

    private func adjustScroll() {
        guard !filtered.isEmpty else { scrollOffset = 0; return }
        let bodyHeight = max(3, Terminal.height - 4)
        let width = Terminal.width

        if selected < scrollOffset { scrollOffset = selected }

        // Rows can be up to two lines tall (wrapped summaries), so scroll by the
        // real rendered line count rather than by issue index: advance the offset
        // until the selected row's lines fit within the body.
        while scrollOffset < selected {
            var lines = 0
            for i in scrollOffset...selected where filtered.indices.contains(i) {
                lines += TUIView.rowHeight(filtered[i], terminalWidth: width)
            }
            if lines <= bodyHeight { break }
            scrollOffset += 1
        }
    }

    // MARK: - Screens

    private func drawList() {
        let title = customJQL != nil ? "custom JQL" : filter
        let frame = TUIView.renderList(
            title: title,
            issues: filtered,
            selected: selected,
            scrollOffset: scrollOffset,
            filterInput: nil,
            message: message
        )
        FileHandle.standardOutput.write(frame.data(using: .utf8)!)
    }

    private func showDetail() async {
        guard filtered.indices.contains(selected), let key = filtered[selected].key else { return }
        message = "Loading \(key)…"; drawList()
        guard let full = await client.fetchIssue(key: key) else {
            message = "Failed to load \(key)."; drawList(); return
        }
        func draw(_ status: String?) {
            let frame = TUIView.renderDetail(full, domain: domain, status: status)
            FileHandle.standardOutput.write(frame.data(using: .utf8)!)
        }
        draw(nil)

        detail: while true {
            switch term.readKey() {
            case .char("q"), .escape, .enter, .left:
                break detail
            case .char("o"):
                if let url = URL(string: "\(domain)/browse/\(key)") { NSWorkspace.shared.open(url) }
                draw("Opened \(key) in browser.")
            case .char("y"):
                copyToClipboard("\(domain)/browse/\(key)")
                draw("Copied link: \(domain)/browse/\(key)")
            case .char("e"):
                await editStatus()
                return
            default:
                break
            }
        }
        message = nil
        drawList()
    }

    private func runFilterPrompt() async {
        var input = ""
        while true {
            let frame = TUIView.renderList(
                title: customJQL != nil ? "custom JQL" : filter,
                issues: filtered,
                selected: selected,
                scrollOffset: scrollOffset,
                filterInput: input,
                message: nil
            )
            FileHandle.standardOutput.write(frame.data(using: .utf8)!)

            switch term.readKey() {
            case .enter:
                applyTextFilter(input)
                drawList()
                return
            case .escape:
                drawList()
                return
            case .char(let c) where c == "\u{7F}" || c == "\u{08}":
                if !input.isEmpty { input.removeLast() }
            case .char(let c):
                input.append(c)
            default:
                break
            }
        }
    }

    private func openInBrowser() {
        guard let key = selectedKey else { return }
        if let url = URL(string: "\(domain)/browse/\(key)") {
            NSWorkspace.shared.open(url)
            message = "Opened \(key) in browser."
            drawList()
        }
    }

    // MARK: - Clipboard

    private var selectedKey: String? {
        guard filtered.indices.contains(selected) else { return nil }
        return filtered[selected].key
    }

    private func copyToClipboard(_ text: String) {
        let pb = NSPasteboard.general
        pb.clearContents()
        pb.setString(text, forType: .string)
    }

    /// `y` — copy the browse URL.
    private func copyLink() {
        guard let key = selectedKey else { return }
        let link = "\(domain)/browse/\(key)"
        copyToClipboard(link)
        message = "Copied link: \(link)"
        drawList()
    }

    // MARK: - Edit

    /// `e` — pick an available transition and move the selected issue to it.
    private func editStatus() async {
        guard let key = selectedKey else { return }
        message = "Loading transitions for \(key)…"; drawList()
        guard let transitions = await client.fetchTransitions(key: key), !transitions.isEmpty else {
            message = "No transitions available for \(key)."; drawList(); return
        }

        var pick = 0
        func draw() {
            let frame = TUIView.renderTransitionPicker(key: key, transitions: transitions, selected: pick)
            FileHandle.standardOutput.write(frame.data(using: .utf8)!)
        }
        draw()

        while true {
            switch term.readKey() {
            case .char("q"), .escape, .left:
                message = nil; drawList(); return
            case .up, .char("k"):
                pick = max(0, pick - 1); draw()
            case .down, .char("j"):
                pick = min(transitions.count - 1, pick + 1); draw()
            case .enter:
                let t = transitions[pick]
                let name = t.name ?? ""
                message = "Moving \(key) → \(name)…"; drawList()
                let ok = await client.applyTransition(key: key, transitionId: t.id ?? "")
                await reload()
                message = ok ? "Moved \(key) → \(name)." : "Failed to move \(key)."
                drawList()
                return
            default:
                break
            }
        }
    }
}
