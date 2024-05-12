import Foundation

// MARK: - Transition

struct Transition: Codable {
    let expand: String?
    let transitions: [TransitionElement]?
}

// MARK: - TransitionElement

struct TransitionElement: Codable {
    let id, name: String?
    let to: To?
    let fields: TransitionFields?
}

// MARK: - Fields

struct TransitionFields: Codable {
    let resolution: TransitionIssuetype?
    let issuetype: TransitionIssuetype?
}

// MARK: - Issuetype

struct TransitionIssuetype: Codable {
    let issuetypeRequired: Bool?
    let schema: Schema?
    let name, fieldID: String?
    let operations: [String]?
    let allowedValues: [AllowedValue]?

    enum CodingKeys: String, CodingKey {
        case issuetypeRequired = "required"
        case schema, name
        case fieldID = "fieldId"
        case operations, allowedValues
    }
}

// MARK: - AllowedValue

struct AllowedValue: Codable {
    let allowedValueSelf: String?
    let name, id: String?

    enum CodingKeys: String, CodingKey {
        case allowedValueSelf = "self"
        case name, id
    }
}

// MARK: - Schema

struct Schema: Codable {
    let type, system: String?
}

// MARK: - To

struct To: Codable {
    let toSelf: String?
    let description: String?
    let iconURL: String?
    let name, id: String?
    let statusCategory: TransitionStatusCategory?

    enum CodingKeys: String, CodingKey {
        case toSelf = "self"
        case description
        case iconURL = "iconUrl"
        case name, id, statusCategory
    }
}

// MARK: - StatusCategory

struct TransitionStatusCategory: Codable {
    let statusCategorySelf: String?
    let id: Int?
    let key, colorName, name: String?

    enum CodingKeys: String, CodingKey {
        case statusCategorySelf = "self"
        case id, key, colorName, name
    }
}
