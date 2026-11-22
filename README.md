# ReachBell iOS SDK

The `ReachBell` Swift package registers an iOS device for Apple Push Notification service (APNs) with [ReachBell](https://reachbell.com), links it to your user id, and tags it for segmentation. Sending pushes and campaigns happens from your backend with the ReachBell server SDKs.

- iOS 13+ (Xcode 14+, Swift 5.7+)
- No dependencies
- Safe to use under Swift 6 strict concurrency (`ReachBell` is `Sendable`)

## Install

In Xcode choose **File > Add Package Dependencies...** and enter:

```
https://github.com/reachbell/reachbell-ios
```

Or in `Package.swift`:

```swift
dependencies: [
    .package(url: "https://github.com/reachbell/reachbell-ios", from: "1.0.0")
],
targets: [
    .target(name: "YourApp", dependencies: [
        .product(name: "ReachBell", package: "reachbell-ios")
    ])
]
```

Enable the **Push Notifications** capability on your app target and configure your APNs key in the ReachBell dashboard. Test on a physical device: the iOS Simulator does not receive remote pushes.

APNs tokens only work in the environment that issued them. Builds run from Xcode (development signing) get sandbox tokens; TestFlight and App Store builds get production tokens. The APNs `sandbox` setting applies to every subscriber in a ReachBell project, and ReachBell deactivates a subscriber when Apple rejects its token as a bad device token. So do not flip `sandbox` on your live project to test a development build: every App Store and TestFlight subscriber would be rejected and deactivated on the next send.

Use a separate ReachBell project for development builds instead, with its own API key and `sandbox` on, and keep `sandbox` off in the project your release builds use. Pick the key at build time, for example:

```swift
#if DEBUG
let reachBellKey = "rb_live_..." // development project, APNs sandbox on
#else
let reachBellKey = "rb_live_..." // production project, APNs sandbox off
#endif
ReachBell.shared.configure(apiKey: reachBellKey)
```

## Quick start

```swift
import UIKit
import ReachBell

@main
class AppDelegate: UIResponder, UIApplicationDelegate {
    func application(
        _ application: UIApplication,
        didFinishLaunchingWithOptions launchOptions: [UIApplication.LaunchOptionsKey: Any]? = nil
    ) -> Bool {
        ReachBell.shared.configure(apiKey: "rb_live_...")
        ReachBell.shared.onRegistrationResult = { result in
            if case .failure(let error) = result {
                print("ReachBell registration failed: \(error)")
            }
        }
        Task { try? await ReachBell.shared.requestAuthorizationAndRegister() }
        return true
    }

    func application(
        _ application: UIApplication,
        didRegisterForRemoteNotificationsWithDeviceToken deviceToken: Data
    ) {
        ReachBell.shared.setAPNsToken(deviceToken)
    }
}
```

SwiftUI apps attach the same `AppDelegate` with `@UIApplicationDelegateAdaptor(AppDelegate.self)`.

## API

| Member | Description |
| --- | --- |
| `ReachBell.shared` | The shared, thread-safe instance. |
| `configure(apiKey:apiUrl:)` | Sets your public `rb_live_` key. `apiUrl` defaults to `https://api.reachbell.com`. Every request sends `x-api-key`. |
| `requestAuthorizationAndRegister(options:) async throws -> Bool` | Asks for notification permission (`[.alert, .sound, .badge]` by default) and calls `registerForRemoteNotifications()`. Throws `.notificationAuthorizationDenied` when permission is refused. iOS only. |
| `setAPNsToken(_ deviceToken: Data)` | Converts the token to lowercase hex, persists it and registers the subscriber in the background with `POST /subscribers { token, tokenType: "apns", platform: "ios", externalId?, previousToken? }`. When the token differs from the last registered one, `previousToken` carries the old token and ReachBell moves its tags and external id to the new one. |
| `onRegistrationResult` | Optional `@Sendable (Result<Void, ReachBellError>) -> Void` called after every registration triggered by `setAPNsToken(_:)`. It runs on a background thread, so hop to the main actor before touching UI. |
| `register() async throws` | Registers the stored token again (for example to retry after a failure reported to `onRegistrationResult`). Throws `.noToken` if no token is stored. |
| `waitForPendingRegistration() async` | Waits for the background registration started by `setAPNsToken(_:)` to finish. |
| `apnsToken: String?` | The stored device token as lowercase hex. |
| `externalId: String?` | The stored external user id. |
| `identify(_ externalId: String) async throws` | Calls `POST /subscribers/identify`. Before a token exists it does not throw: the id is stored and sent with the next registration. |
| `tag(_ tags: [String]) async throws` | Calls `POST /subscribers/tag`. Throws `.noToken` without a token. |
| `untag(_ tags: [String]) async throws` | Calls `POST /subscribers/untag`. Throws `.noToken` without a token. |
| `reset()` | Call on logout. Forgets the stored token and external id immediately, cancels an in-flight registration (its `onRegistrationResult` is not called) and calls `POST /subscribers/unidentify` for the old token in the background, ignoring errors. The next registration, `identify`, `tag` and `untag` wait for that call. |

`identify`, `tag` and `untag` wait for an in-flight registration before sending, so calling them right after `setAPNsToken(_:)` is safe.

The token and external id are persisted in `UserDefaults`, so they survive a relaunch. To use an app group or a custom suite, or to inject a transport in tests, create your own instance:

```swift
let reachBell = ReachBell(
    userDefaults: UserDefaults(suiteName: "group.com.example.app")!,
    transport: URLSessionTransport(session: .shared)
)
```

Requests send a `User-Agent` such as `ReachBell/1.0.0 (iPhone; CPU iPhone OS 17_4 like Mac OS X; iPhone15,2) reachbell-ios/1.0.0` and `os`, `osVersion` and `device` fields, so the dashboard shows the device as iOS mobile or tablet.

`ReachBellTransport` is a one-method protocol (`send(_ request: URLRequest) async throws -> (Data, URLResponse)`) that you can implement to stub the network. `URLSessionTransport` cancels its data task when the calling task is cancelled; custom transports should honour cancellation too.

## Errors

Every throwing method throws `ReachBellError`:

| Case | Meaning |
| --- | --- |
| `.notConfigured` | `configure(apiKey:)` was not called. |
| `.notificationAuthorizationDenied` | The user denied notification permission. |
| `.noToken` | No APNs token yet. Register for push first. |
| `.encodingFailed(Error)` | The request body could not be JSON-encoded. |
| `.network(underlying:)` | Transport failed (offline, timeout, TLS, ...). |
| `.server(status:body:)` | Non-2xx HTTP response; `body` is the raw payload. `403` on registration means the plan's subscriber limit is reached. |
| `.invalidResponse` | The response was not a valid HTTP response or not the expected JSON. |
| `.rejected(reason:)` | The API answered 2xx with `success: false`, for example `reason: "subscriber_not_found"`. |

```swift
do {
    try await ReachBell.shared.tag(["pro", "ios"])
} catch ReachBellError.noToken {
    print("Register for push first")
} catch ReachBellError.rejected(let reason) {
    print("Rejected: \(reason ?? "unknown")")
} catch ReachBellError.server(let status, _) {
    print("HTTP \(status)")
} catch {
    print(error.localizedDescription)
}
```

## Development

```
swift build
swift test
xcodebuild -scheme ReachBell -destination 'generic/platform=iOS' build
```

## License

MIT. See [LICENSE](LICENSE).
