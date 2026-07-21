import Foundation

/// Shared helpers used by both Create and Clone for reading and normalizing
/// issue fields for Jira create/update POST bodies.
extension Jira {
    func rawIssueFields(key: String) async -> [String: Any]? {
        guard let (data, response) = try? await URLSession.shared.data(for: makeRequest("/rest/api/2/issue/\(key)")),
              (response as? HTTPURLResponse)?.statusCode == 200,
              let root = try? JSONSerialization.jsonObject(with: data) as? [String: Any],
              let fields = root["fields"] as? [String: Any] else {
            return nil
        }
        return fields
    }

    func editableFieldIDs(key: String) async -> Set<String>? {
        guard let (data, response) = try? await URLSession.shared.data(for: makeRequest("/rest/api/2/issue/\(key)/editmeta")),
              (response as? HTTPURLResponse)?.statusCode == 200,
              let root = try? JSONSerialization.jsonObject(with: data) as? [String: Any],
              let fields = root["fields"] as? [String: Any] else {
            return nil
        }
        return Set(fields.keys)
    }

    func currentUsername() async -> String? {
        if case .success(let me) = (try? await request(configuration: makeRequest("/rest/api/2/myself")) as Result<UserModel, Error>) ?? .failure(NSError()) {
            return me.name
        }
        return nil
    }

    /// Reduce a read value to a valid write value per its Jira field shape.
    /// - Strings (Epic Link bare key, nfeed IDs) → as-is
    /// - Arrays → map each element recursively
    /// - Objects → reduce to {id:…}, {name:…}, or {value:…}
    /// - NSNull / greenhopper junk → nil (dropped)
    func normalizeForWrite(_ value: Any) -> Any? {
        if value is NSNull { return nil }
        if let s = value as? String {
            if s.contains("com.atlassian.greenhopper") { return nil }
            return s
        }
        if value is Int || value is Double || value is Bool { return value }
        if let arr = value as? [Any] {
            let mapped = arr.compactMap { normalizeForWrite($0) }
            return mapped.isEmpty ? nil : mapped
        }
        if let dict = value as? [String: Any] {
            // User fields.
            if dict["accountId"] != nil || (dict["name"] != nil && dict["emailAddress"] != nil) {
                if let name = dict["name"] as? String { return ["name": name] }
            }
            if let id = dict["id"] { return ["id": id] }
            if let name = dict["name"] as? String { return ["name": name] }
            if let value = dict["value"] as? String { return ["value": value] }
            return nil
        }
        return nil
    }
}
