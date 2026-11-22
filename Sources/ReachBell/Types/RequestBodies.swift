import Foundation

struct RegisterSubscriberBody: Encodable, Sendable {
    let token: String
    let tokenType: String
    let platform: String
    let externalId: String?
    /// C2: the previously registered subscriber token; the API moves its tags and externalId over.
    let previousToken: String?
    let os: String?
    let osVersion: String?
    let device: String?
}

struct IdentifyBody: Encodable, Sendable {
    let token: String
    let externalId: String
}

struct UnidentifyBody: Encodable, Sendable {
    let token: String
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
