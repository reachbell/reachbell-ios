import Foundation

/// What the SDK tells the API about the device. The API parses the User-Agent with UAParser and falls
/// back to the `os` / `osVersion` / `device` body fields, so both are sent.
///
/// Only thread-safe sources are used (`ProcessInfo`, `uname`), not `UIDevice`, which is main-actor bound.
struct DeviceInfo: Sendable, Equatable {
    /// `iOS`, `iPadOS` reports as `iOS` too (UAParser does the same).
    let os: String
    /// Dotted version, for example `17.4`.
    let osVersion: String
    /// `mobile` or `tablet` (the values UAParser uses), nil when unknown (macOS).
    let deviceType: String?
    /// The User-Agent comment, for example `iPhone; CPU iPhone OS 17_4 like Mac OS X`.
    let userAgentComment: String
    /// Hardware identifier such as `iPhone15,2`, nil when unknown.
    let model: String?

    static let current = DeviceInfo.detect()

    var userAgent: String {
        let version = ReachBellConstants.sdkVersion
        var comment = userAgentComment
        if let model = model {
            comment += "; \(model)"
        }
        // The leading product token must not contain "ios": UAParser takes the first `ios/<version>` it
        // finds, so `reachbell-ios/1.0.0` first would be recorded as iOS 1.0.0.
        return "ReachBell/\(version) (\(comment)) reachbell-ios/\(version)"
    }

    static func detect() -> DeviceInfo {
        let v = ProcessInfo.processInfo.operatingSystemVersion
        let dotted = v.patchVersion > 0
            ? "\(v.majorVersion).\(v.minorVersion).\(v.patchVersion)"
            : "\(v.majorVersion).\(v.minorVersion)"
        let underscored = dotted.replacingOccurrences(of: ".", with: "_")
        let machine = hardwareIdentifier()

        #if os(iOS) && !targetEnvironment(macCatalyst)
        let isPad = machine?.hasPrefix("iPad") ?? false
        return DeviceInfo(
            os: "iOS",
            osVersion: dotted,
            deviceType: isPad ? "tablet" : "mobile",
            userAgentComment: isPad
                ? "iPad; CPU OS \(underscored) like Mac OS X"
                : "iPhone; CPU iPhone OS \(underscored) like Mac OS X",
            model: machine
        )
        #elseif os(macOS) || targetEnvironment(macCatalyst)
        return DeviceInfo(
            os: "macOS",
            osVersion: dotted,
            deviceType: nil,
            userAgentComment: "Macintosh; Intel Mac OS X \(underscored)",
            model: nil
        )
        #else
        return DeviceInfo(os: "iOS", osVersion: dotted, deviceType: nil, userAgentComment: "CPU OS \(underscored)", model: machine)
        #endif
    }

    /// `iPhone15,2`, `iPad13,1`; on the Simulator the simulated model, not the host CPU.
    private static func hardwareIdentifier() -> String? {
        if let simulated = ProcessInfo.processInfo.environment["SIMULATOR_MODEL_IDENTIFIER"], !simulated.isEmpty {
            return simulated
        }
        var info = utsname()
        guard uname(&info) == 0 else { return nil }
        let machine = withUnsafeBytes(of: &info.machine) { raw -> String in
            let bytes = raw.prefix { $0 != 0 }
            return String(decoding: bytes, as: UTF8.self)
        }
        guard machine.hasPrefix("iPhone") || machine.hasPrefix("iPad") || machine.hasPrefix("iPod") else {
            return nil
        }
        return machine
    }
}
