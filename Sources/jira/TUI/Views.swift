import Foundation

/// A named, saved view in the interactive browser. Resolves to either a preset
/// filter (understood by `Jira.buildJQL`) or a raw JQL query.
struct JiraView: Codable, Equatable {
    var name: String
    /// Human explanation of what this view shows (kept visible in the picker).
    var about: String?
    /// Preset filter name (openSprints | undone | all | … | <status>).
    var filter: String?
    /// Raw JQL. When set, overrides `filter`.
    var jql: String?

    /// The (filter, customJQL) pair to hand to `client.fetchIssues`.
    var resolved: (filter: String, customJQL: String?) {
        if let jql = jql, !jql.isEmpty { return ("custom", jql) }
        return (filter ?? "openSprints", nil)
    }
}

/// Loads and persists the user's views to Application Support, seeding sensible
/// defaults on first run so the file is there to edit.
enum ViewStore {
    private static var fileURL: URL {
        FileManager.default.urls(for: .applicationSupportDirectory, in: .userDomainMask)
            .first!.appendingPathComponent("swifty-jira-views.json")
    }

    /// The built-in starter views, each with a plain-language explanation.
    static let defaults: [JiraView] = [
        JiraView(name: "Open sprints",
                 about: "Assigned to me, in currently active sprints.",
                 filter: "openSprints", jql: nil),
        JiraView(name: "Open + future sprints",
                 about: "Assigned to me, in active or upcoming sprints.",
                 filter: "openAndFutureSprints", jql: nil),
        JiraView(name: "Undone",
                 about: "Assigned to me, anything not Done / Dev Complete.",
                 filter: "undone", jql: nil),
        JiraView(name: "All mine",
                 about: "Every issue assigned to me, any status.",
                 filter: "all", jql: nil),
        JiraView(name: "In progress",
                 about: "Assigned to me, status = In Progress.",
                 filter: "In Progress", jql: nil),
    ]

    static func load() -> [JiraView] {
        guard let data = try? Data(contentsOf: fileURL),
              let views = try? JSONDecoder().decode([JiraView].self, from: data),
              !views.isEmpty else {
            save(defaults)
            return defaults
        }
        return views
    }

    @discardableResult
    static func save(_ views: [JiraView]) -> Bool {
        let encoder = JSONEncoder()
        encoder.outputFormatting = [.prettyPrinted, .sortedKeys]
        guard let data = try? encoder.encode(views) else { return false }
        try? FileManager.default.createDirectory(
            at: fileURL.deletingLastPathComponent(), withIntermediateDirectories: true)
        return (try? data.write(to: fileURL)) != nil
    }

    static var path: String { fileURL.path }
}
