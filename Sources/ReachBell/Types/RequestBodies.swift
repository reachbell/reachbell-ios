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
    /// C1a: when `externalId` is nil, encode `"externalId": null` (clear) instead of omitting the key.
    var clearExternalId = false

    private enum CodingKeys: String, CodingKey {
        case token, tokenType, platform, externalId, previousToken, os, osVersion, device
    }

    func encode(to encoder: Encoder) throws {
        var container = encoder.container(keyedBy: CodingKeys.self)
        try container.encode(token, forKey: .token)
        try container.encode(tokenType, forKey: .tokenType)
        try container.encode(platform, forKey: .platform)
        if let externalId = externalId {
            try container.encode(externalId, forKey: .externalId)
        } else if clearExternalId {
            try container.encodeNil(forKey: .externalId)
        }
        try container.encodeIfPresent(previousToken, forKey: .previousToken)
        try container.encodeIfPresent(os, forKey: .os)
        try container.encodeIfPresent(osVersion, forKey: .osVersion)
        try container.encodeIfPresent(device, forKey: .device)
    }
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
