#if canImport(UIKit) && canImport(UserNotifications) && !os(watchOS)
import UIKit
import UserNotifications

enum NotificationAuthorization {
    static func request(options: UNAuthorizationOptions) async throws -> Bool {
        try await withCheckedThrowingContinuation { continuation in
            UNUserNotificationCenter.current().requestAuthorization(options: options) { granted, error in
                if let error = error {
                    continuation.resume(throwing: error)
                } else {
                    continuation.resume(returning: granted)
                }
            }
        }
    }

    @MainActor
    static func registerForRemoteNotifications() {
        UIApplication.shared.registerForRemoteNotifications()
    }
}
#endif
