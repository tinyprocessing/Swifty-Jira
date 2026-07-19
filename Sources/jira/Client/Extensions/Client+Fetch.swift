import Foundation

/// Fetch-only methods that return models (no printing).
/// Shared by the print/JSON commands and the interactive TUI.
extension Jira {
    /// Builds a JQL string from a preset filter or a custom query.
    static func buildJQL(filter: String, customJQL: String?) -> String {
        if let customJQL = customJQL, !customJQL.isEmpty {
            return customJQL
        }
        var filterPart = filter
        switch filterPart {
        case "undone":
            filterPart = "+AND+status!=Done+AND+status!=%22Dev+Complete%22"
        case "backlog":
            filterPart =
                "+AND+project=*MEM*+AND+(sprint+is+EMPTY+OR+Sprint+not+in+(openSprints(),+futureSprints()))+AND+resolution+=+Unresolved+and+status+!=+Closed"
        case "all":
            filterPart = ""
        case "openSprints":
            filterPart = "+AND+Sprint+in+openSprints()"
        case "openAndFutureSprints":
            filterPart = "+AND+(Sprint+in+openSprints()+OR+Sprint+in+futureSprints())"
        default:
            filterPart = "+AND+status=\(filterPart)"
        }
        return "assignee=currentUser()" + filterPart
    }

    /// A human-readable form of the JQL a filter/JQL resolves to (for the TUI
    /// view picker). Decodes the URL-encoding `buildJQL` produces.
    static func readableJQL(filter: String, customJQL: String?) -> String {
        let raw = buildJQL(filter: filter, customJQL: customJQL)
        return raw
            .replacingOccurrences(of: "+", with: " ")
            .replacingOccurrences(of: "%22", with: "\"")
            .replacingOccurrences(of: "%20", with: " ")
    }

    /// Returns issues matching a filter/JQL, or nil on failure.
    func fetchIssues(filter: String, customJQL: String? = nil) async -> SearchIssues? {
        let jql = Jira.buildJQL(filter: filter, customJQL: customJQL)
        let result: Result<SearchIssues, Error> =
            (try? await request(configuration: makeRequest("/rest/api/2/search?jql=\(jql)"))) ?? .failure(NSError())
        if case .success(let response) = result {
            return response
        }
        return nil
    }

    /// Returns a single issue with full fields, or nil on failure.
    func fetchIssue(key: String) async -> Issue? {
        let path = "/rest/api/2/issue/\(key)?fields=summary,description,status,issuetype,priority,assignee,reporter,project,created,updated,parent,subtasks,issuelinks,labels,comment"
        let result: Result<Issue, Error> =
            (try? await request(configuration: makeRequest(path))) ?? .failure(NSError())
        if case .success(let issue) = result {
            return issue
        }
        return nil
    }
}
