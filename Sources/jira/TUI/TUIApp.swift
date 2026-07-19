import AppKit
import Foundation

/// Interactive keyboard-driven Jira browser (k9s-style).
final class TUIApp {
    private let client: Jira
    private let domain: String
    private var filter: String
    private var customJQL: String?

    /// User-configurable saved views (the `f` picker). Loaded from disk.
    private var views: [JiraView]
    /// Name of the currently active view (shown in the header).
    private var activeViewName: String

    private var allIssues: [Issue] = []
    private var filtered: [Issue] = []
    /// Total matches reported by the server (may exceed what was fetched).
    private var serverTotal = 0
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

        var loaded = ViewStore.load()
        if let customJQL = customJQL, !customJQL.isEmpty {
            // Launched with --jql: surface it as an ad-hoc active view.
            let adhoc = JiraView(name: "Launch JQL", about: "Passed via --jql at launch.", filter: nil, jql: customJQL)
            loaded.insert(adhoc, at: 0)
            self.activeViewName = adhoc.name
        } else if let match = loaded.first(where: { $0.filter == filter && $0.jql == nil }) {
            self.activeViewName = match.name
        } else {
            // Launched with a preset/status not in the saved list — add it.
            let adhoc = JiraView(name: filter, about: "Launched with --filter \(filter).", filter: filter, jql: nil)
            loaded.insert(adhoc, at: 0)
            self.activeViewName = adhoc.name
        }
        self.views = loaded
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
                await showViewPicker()
            case .char("o"):
                openInBrowser()
            case .char("y"):
                copyLink()
            case .char("e"):
                await editIssue()
            case .char("r"):
                message = "Refreshing…"; drawList()
                await reload(); drawList()
            default:
                break
            }
        }
    }

    // MARK: - Views

    /// Switch to `view`: resolve its filter/JQL, clear any text search, re-fetch.
    private func applyView(_ view: JiraView) async {
        let resolved = view.resolved
        filter = resolved.filter
        customJQL = resolved.customJQL
        activeViewName = view.name
        textFilter = ""
        selected = 0
        scrollOffset = 0
        message = "\(view.name) — loading…"
        drawList()
        await reload()
        drawList()
    }

    /// `f` — the view picker: a transparent, configurable list of saved views.
    /// Each row shows the view name, its explanation and the exact JQL it runs.
    /// `n` adds a view from a raw JQL, `x` deletes the selected one.
    private func showViewPicker() async {
        var pick = views.firstIndex(where: { $0.name == activeViewName }) ?? 0
        func draw(_ note: String? = nil) {
            let rows = views.map { view -> (String, String, String) in
                let r = view.resolved
                return (view.name, view.about ?? "", Jira.readableJQL(filter: r.filter, customJQL: r.customJQL))
            }
            let frame = TUIView.renderViewPicker(views: rows, selected: pick, activeName: activeViewName, note: note)
            FileHandle.standardOutput.write(frame.data(using: .utf8)!)
        }
        draw()

        while true {
            switch term.readKey() {
            case .char("q"), .escape, .left:
                drawList(); return
            case .up, .char("k"):
                pick = max(0, pick - 1); draw()
            case .down, .char("j"):
                pick = min(views.count - 1, pick + 1); draw()
            case .enter:
                guard views.indices.contains(pick) else { drawList(); return }
                await applyView(views[pick])
                return
            case .char("n"):
                if let created = addViewInteractively() {
                    views.append(created)
                    ViewStore.save(views)
                    pick = views.count - 1
                    draw("Added “\(created.name)”. Saved to \(ViewStore.path)")
                } else {
                    draw()
                }
            case .char("x"):
                guard views.indices.contains(pick), views.count > 1 else {
                    draw("Can't delete the last remaining view."); break
                }
                let removed = views.remove(at: pick)
                ViewStore.save(views)
                pick = min(pick, views.count - 1)
                draw("Deleted “\(removed.name)”.")
            default:
                break
            }
        }
    }

    /// Prompts for a name and a JQL query and returns a new view (nil if
    /// cancelled or empty).
    private func addViewInteractively() -> JiraView? {
        guard let name = editText(title: "New view · name", initial: "", multiline: false),
              !name.trimmingCharacters(in: .whitespaces).isEmpty else { return nil }
        guard let jql = editText(title: "New view · JQL (e.g. assignee=currentUser() AND status=\"In Review\")", initial: "", multiline: false),
              !jql.trimmingCharacters(in: .whitespaces).isEmpty else { return nil }
        return JiraView(name: name.trimmingCharacters(in: .whitespaces),
                        about: "Custom view.",
                        filter: nil,
                        jql: jql.trimmingCharacters(in: .whitespaces))
    }

    private func reload() async {
        if let response = await client.fetchIssues(filter: filter, customJQL: customJQL) {
            allIssues = response.issues ?? []
            serverTotal = response.total ?? allIssues.count
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

    /// Header count: reflects text-search matches and any server-side truncation.
    private func countLabel() -> String {
        if !textFilter.isEmpty {
            return "\(filtered.count)/\(allIssues.count) matched"
        }
        if serverTotal > allIssues.count {
            return "\(allIssues.count) of \(serverTotal) (truncated)"
        }
        return "\(allIssues.count) issues"
    }

    private func drawList() {
        let frame = TUIView.renderList(
            title: activeViewName,
            issues: filtered,
            selected: selected,
            scrollOffset: scrollOffset,
            filterInput: nil,
            message: message,
            countLabel: countLabel()
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
                await editIssue(key: key)
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
                title: activeViewName,
                issues: filtered,
                selected: selected,
                scrollOffset: scrollOffset,
                filterInput: input,
                message: nil,
                countLabel: countLabel()
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

    /// Jira Server Epic Link custom field. Overridable per instance.
    private static var epicFieldId: String {
        ProcessInfo.processInfo.environment["JIRA_EPIC_FIELD"] ?? "customfield_10007"
    }

    private enum FieldID {
        case summary, description, status, priority, assignee, labels, epicLink, customJSON
    }

    private struct EditableField {
        let id: FieldID
        let label: String
        let kind: TUIView.EditKind
        var value: String
    }

    /// `e` — full field editor for the selected issue (summary, description,
    /// status, priority, assignee, labels, Epic Link, plus a raw-JSON escape
    /// hatch for any other custom field).
    private func editIssue(key providedKey: String? = nil) async {
        guard let key = providedKey ?? selectedKey else { return }
        message = "Loading \(key)…"; drawList()
        guard let full = await client.fetchIssue(key: key) else {
            message = "Failed to load \(key)."; drawList(); return
        }
        let f = full.fields

        var fields: [EditableField] = [
            EditableField(id: .summary, label: "Summary", kind: .singleLine, value: f?.summary ?? ""),
            EditableField(id: .description, label: "Description", kind: .multiLine, value: f?.description ?? ""),
            EditableField(id: .status, label: "Status", kind: .transition, value: f?.status?.name ?? ""),
            EditableField(id: .priority, label: "Priority", kind: .singleLine, value: f?.priority?.name ?? ""),
            EditableField(id: .assignee, label: "Assignee (login)", kind: .singleLine, value: f?.assignee?.name ?? ""),
            EditableField(id: .labels, label: "Labels (comma-separated)", kind: .singleLine, value: labelsString(f?.labels)),
            EditableField(id: .epicLink, label: "Epic Link (issue key)", kind: .singleLine, value: ""),
            EditableField(id: .customJSON, label: "Custom field (raw JSON object)", kind: .json, value: ""),
        ]

        var sel = 0
        var note: String?
        func draw() {
            let frame = TUIView.renderEditMenu(key: key, fields: fields.map { ($0.label, $0.value, $0.kind) }, selected: sel, note: note)
            FileHandle.standardOutput.write(frame.data(using: .utf8)!)
        }
        draw()

        editLoop: while true {
            switch term.readKey() {
            case .char("q"), .escape, .left:
                break editLoop
            case .up, .char("k"):
                sel = max(0, sel - 1); note = nil; draw()
            case .down, .char("j"):
                sel = min(fields.count - 1, sel + 1); note = nil; draw()
            case .enter:
                let field = fields[sel]
                switch field.kind {
                case .transition:
                    let moved = await pickAndApplyTransition(for: key)
                    if let refreshed = await client.fetchIssue(key: key) {
                        fields[sel].value = refreshed.fields?.status?.name ?? field.value
                    }
                    note = moved.map { $0 ? "Status changed." : "Status change failed." }
                    draw()
                case .singleLine, .json:
                    if let edited = editText(title: "\(key) · \(field.label)", initial: field.value, multiline: false) {
                        fields[sel].value = edited
                        note = await saveField(fields[sel], key: key)
                    }
                    draw()
                case .multiLine:
                    if let edited = editText(title: "\(key) · \(field.label)", initial: field.value, multiline: true) {
                        fields[sel].value = edited
                        note = await saveField(fields[sel], key: key)
                    }
                    draw()
                }
            default:
                break
            }
        }
        // A refresh keeps the list in sync with any saved edits.
        message = "Refreshing…"; drawList()
        await reload()
        message = nil
        drawList()
    }

    /// Saves one field. Returns a human-readable status note.
    private func saveField(_ field: EditableField, key: String) async -> String {
        let v = field.value.trimmingCharacters(in: .whitespacesAndNewlines)
        var payload: [String: Any] = [:]

        switch field.id {
        case .summary:
            payload["summary"] = field.value
        case .description:
            payload["description"] = field.value
        case .priority:
            guard !v.isEmpty else { return "Priority left unchanged (empty)." }
            payload["priority"] = ["name": v]
        case .assignee:
            payload["assignee"] = v.isEmpty ? NSNull() : ["name": v]
        case .labels:
            payload["labels"] = v.split(separator: ",")
                .map { $0.trimmingCharacters(in: .whitespaces) }
                .filter { !$0.isEmpty }
        case .epicLink:
            guard !v.isEmpty else { return "Epic Link left unchanged (empty)." }
            payload[TUIApp.epicFieldId] = v  // bare issue key on Jira Server
        case .customJSON:
            guard !v.isEmpty else { return "No JSON entered." }
            guard let data = v.data(using: .utf8),
                  let obj = try? JSONSerialization.jsonObject(with: data),
                  let dict = obj as? [String: Any] else {
                return "Invalid JSON — expected an object like {\"customfield_X\":…}."
            }
            payload = dict
        case .status:
            return "Use enter on Status to change it."
        }

        let ok = await client.updateIssueFields(key: key, fields: payload)
        return ok ? "Saved \(field.label)." : "Failed to save \(field.label) (check value/permissions)."
    }

    /// Presents the transition picker and applies the choice.
    /// Returns nil if cancelled, true/false for applied success.
    private func pickAndApplyTransition(for key: String) async -> Bool? {
        guard let transitions = await client.fetchTransitions(key: key), !transitions.isEmpty else {
            return false
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
                return nil
            case .up, .char("k"):
                pick = max(0, pick - 1); draw()
            case .down, .char("j"):
                pick = min(transitions.count - 1, pick + 1); draw()
            case .enter:
                return await client.applyTransition(key: key, transitionId: transitions[pick].id ?? "")
            default:
                break
            }
        }
    }

    /// A minimal in-place text input. Printable keys append; Backspace deletes.
    /// In multiline mode, Enter inserts a newline and Ctrl-S saves; otherwise
    /// Enter saves. Esc cancels (returns nil).
    private func editText(title: String, initial: String, multiline: Bool) -> String? {
        var text = initial
        func draw() {
            let frame = TUIView.renderTextEditor(title: title, text: text, multiline: multiline)
            FileHandle.standardOutput.write(frame.data(using: .utf8)!)
        }
        draw()
        while true {
            switch term.readKey() {
            case .escape:
                return nil
            case .enter:
                if multiline { text.append("\n"); draw() }
                else { return text }
            case .char(let c) where c == "\u{7F}" || c == "\u{08}":
                if !text.isEmpty { text.removeLast(); draw() }
            case .char(let c) where c == "\u{13}":  // Ctrl-S
                if multiline { return text }
            case .char(let c) where c == "\u{15}":  // Ctrl-U — clear line
                text = ""; draw()
            case .char(let c):
                // Ignore other control chars.
                if let scalar = c.unicodeScalars.first, scalar.value < 0x20 { break }
                text.append(c); draw()
            default:
                break
            }
        }
    }

    private func labelsString(_ labels: [JSONAny]?) -> String {
        guard let labels = labels else { return "" }
        return labels.compactMap { ($0.value as? String) }.joined(separator: ", ")
    }
}
