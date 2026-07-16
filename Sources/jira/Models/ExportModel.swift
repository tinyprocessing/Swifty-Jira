import Foundation

// MARK: - Claude-friendly flat export of a Jira issue

struct IssueExport: Encodable {
    struct LinkedIssue: Encodable {
        let key: String
        let summary: String
        let status: String
        let type: String
        let linkRelation: String  // e.g. "blocks", "is blocked by", "relates to"
    }

    struct SubtaskExport: Encodable {
        let key: String
        let summary: String
        let status: String
        let assignee: String?
    }

    struct CommentExport: Encodable {
        let author: String
        let created: String
        let body: String
    }

    let key: String
    let summary: String
    let description: String?
    let status: String
    let type: String
    let priority: String?
    let assignee: String?
    let reporter: String?
    let project: String?
    let created: String?
    let updated: String?
    let parent: String?
    let parentSummary: String?
    let subtasks: [SubtaskExport]
    let linkedIssues: [LinkedIssue]
    let comments: [CommentExport]
    let labels: [String]
    let url: String?
}
