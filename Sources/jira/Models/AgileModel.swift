import Foundation

// MARK: - Agile API models (/rest/agile/1.0/)

struct BoardList: Codable {
    let maxResults: Int?
    let startAt: Int?
    let total: Int?
    let isLast: Bool?
    let values: [Board]?
}

struct Board: Codable {
    let id: Int?
    let name: String?
    let type: String?
}

struct SprintList: Codable {
    let maxResults: Int?
    let startAt: Int?
    let isLast: Bool?
    let values: [Sprint]?
}

struct Sprint: Codable {
    let id: Int?
    let state: String?
    let name: String?
    let startDate: String?
    let endDate: String?
    let goal: String?
    let originBoardId: Int?
}
