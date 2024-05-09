import Foundation

// MARK: - SearchIssues

struct SearchIssues: Codable {
    let expand: String?
    let startAt, maxResults, total: Int?
    let issues: [Issue]?
}

// MARK: - Issue

struct Issue: Codable {
    let expand, id: String?
    let issueSelf: String?
    let key: String?
    let fields: IssueFields?

    enum CodingKeys: String, CodingKey {
        case expand, id
        case issueSelf = "self"
        case key, fields
    }
}

// MARK: - IssueFields

struct IssueFields: Codable {
    let parent: Parent?
    let lastViewed: String?
    let labels: [JSONAny]?
    let issuelinks: [JSONAny]?
    let assignee: Assignee?
    let components: [JSONAny]?
    let subtasks: [Issue]?
    let reporter: Assignee?
    let progress: Progress?
    let votes: Votes?
    let issuetype: Issuetype?
    let project: Project?
    let watches: Watches?
    let updated: String?
    let summary: String?
    let priority: Priority?
    let status: Status?
    let creator: Assignee?
    let aggregateprogress: Progress?
    let workratio: Int?
    let created: String?

    enum CodingKeys: String, CodingKey {
        case parent
        case issuelinks
        case lastViewed
        case assignee
        case labels
        case components
        case subtasks, reporter
        case progress, votes
        case issuetype
        case project
        case watches
        case updated
        case summary
        case priority
        case status
        case creator
        case aggregateprogress
        case workratio
        case created
    }
}

// MARK: - Progress

struct Progress: Codable {
    let progress, total: Int?
}

// MARK: - Assignee

struct Assignee: Codable {
    let assigneeSelf: String?
    let name, key, emailAddress: String?
    let avatarUrls: AvatarUrls?
    let displayName: String?
    let active: Bool?
    let timeZone: String?

    enum CodingKeys: String, CodingKey {
        case assigneeSelf = "self"
        case name, key, emailAddress, avatarUrls, displayName, active, timeZone
    }
}

// MARK: - Customfield21224

struct Customfield21224: Codable {
    let customfield21224_Self: String?
    let value, id: String?
    let disabled: Bool?

    enum CodingKeys: String, CodingKey {
        case customfield21224_Self = "self"
        case value, id, disabled
    }
}

// MARK: - Issuetype

struct Issuetype: Codable {
    let issuetypeSelf: String?
    let id, description: String?
    let iconURL: String?
    let name: String?
    let subtask: Bool?
    let avatarID: Int?

    enum CodingKeys: String, CodingKey {
        case issuetypeSelf = "self"
        case id, description
        case iconURL = "iconUrl"
        case name, subtask
        case avatarID = "avatarId"
    }
}

// MARK: - Parent

struct Parent: Codable {
    let id, key: String?
    let parentSelf: String?
    let fields: ParentFields?

    enum CodingKeys: String, CodingKey {
        case id, key
        case parentSelf = "self"
        case fields
    }
}

// MARK: - ParentFields

struct ParentFields: Codable {
    let summary: String?
    let status: Status?
    let priority: Priority?
    let issuetype: Issuetype?
}

// MARK: - Priority

struct Priority: Codable {
    let prioritySelf: String?
    let iconURL: String?
    let name, id, description: String?

    enum CodingKeys: String, CodingKey {
        case prioritySelf = "self"
        case iconURL = "iconUrl"
        case name, id, description
    }
}

// MARK: - Status

struct Status: Codable {
    let statusSelf: String?
    let description: String?
    let iconURL: String?
    let name, id: String?
    let statusCategory: StatusCategory?

    enum CodingKeys: String, CodingKey {
        case statusSelf = "self"
        case description
        case iconURL = "iconUrl"
        case name, id, statusCategory
    }
}

// MARK: - StatusCategory

struct StatusCategory: Codable {
    let statusCategorySelf: String?
    let id: Int?
    let key, colorName, name: String?

    enum CodingKeys: String, CodingKey {
        case statusCategorySelf = "self"
        case id, key, colorName, name
    }
}

// MARK: - Project

struct Project: Codable {
    let projectSelf: String?
    let id, key, name, projectTypeKey: String?
    let avatarUrls: AvatarUrls?
    let projectCategory: Priority?

    enum CodingKeys: String, CodingKey {
        case projectSelf = "self"
        case id, key, name, projectTypeKey, avatarUrls, projectCategory
    }
}

// MARK: - Votes

struct Votes: Codable {
    let votesSelf: String?
    let votes: Int?
    let hasVoted: Bool?

    enum CodingKeys: String, CodingKey {
        case votesSelf = "self"
        case votes, hasVoted
    }
}

// MARK: - Watches

struct Watches: Codable {
    let watchesSelf: String?
    let watchCount: Int?
    let isWatching: Bool?

    enum CodingKeys: String, CodingKey {
        case watchesSelf = "self"
        case watchCount, isWatching
    }
}
