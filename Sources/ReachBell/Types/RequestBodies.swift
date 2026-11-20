import Foundation

struct RegisterSubscriberBody: Encodable, Sendable {
    let token: String
    let tokenType: String
    let platform: String
    let externalId: String?
}

struct IdentifyBody: Encodable, Sendable {
    let token: String
    let externalId: String
}

struct TagsBody: Encodable, Sendable {
    let token: String
    let tags: [String]
}

struct MutationResponse: Decodable, Sendable {
    let success: Bool
    let updated: Bool?
    let reason: String?
}
