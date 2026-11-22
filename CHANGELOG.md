# Changelog

## Unreleased

- `reset()` calls `POST /subscribers/unidentify` for the stored token (best effort) so the user is unlinked on the server at logout. Later registrations, `identify`, `tag` and `untag` wait for it.
- `POST /subscribers` sends `previousToken` when APNs hands out a new token; ReachBell moves the old subscriber's tags and external id to the new token. The last registered token is stored under `com.reachbell.registeredToken` (a token stored by 1.0.0 is treated as registered).
- `reset()` drops the result of an in-flight registration: `onRegistrationResult` is not called and the result is not persisted. `URLSessionTransport` now cancels the data task when the calling task is cancelled.
- Requests send a `User-Agent` (`ReachBell/<ver> (iPhone; CPU iPhone OS <ver> like Mac OS X; <model>) reachbell-ios/<ver>`) and `os`, `osVersion`, `device` fields, so subscribers are recorded as iOS mobile or tablet instead of Unknown / desktop.
- After `reset()`, the first `POST /subscribers` without an external id sends `"externalId": null`, so a logout whose unidentify failed offline is repaired. The flag is stored in `UserDefaults` (`com.reachbell.externalIdClearPending`) and dropped after a successful registration.
- `register()` runs on the same chain as `setAPNsToken(_:)` and `reset()`: it waits for work queued before it, `identify`, `tag`, `untag` and `reset()` wait for it, and `reset()` cancels it (it then throws `CancellationError` and its result is not persisted).
- `identify(_:)` stores the id and drops a pending `"externalId": null` in one step, so a registration racing with it can no longer send `null` after the new id. If `reset()` runs before its request goes out, `identify(_:)` does not send it.
- `reset()` unidentifies both the registered and the stored token when an APNs rotation has not been registered yet.
- README: `reset()` forgets the APNs token; call `registerForRemoteNotifications()` again for the next user.
- README: use a separate ReachBell project with APNs sandbox on for development builds instead of flipping `sandbox` on the live project.

## 1.0.0

- Initial release.
- `configure(apiKey:apiUrl:)`, `requestAuthorizationAndRegister(options:)`, `setAPNsToken(_:)` with background registration and `onRegistrationResult`.
- `identify(_:)` (stashes the external id until a token exists), `tag(_:)`, `untag(_:)`, `register()`, `reset()`.
- Token and external id persisted in `UserDefaults` with an injectable suite.
- Injectable `ReachBellTransport` for testing.
- `ReachBellError.rejected(reason:)` for 2xx responses with `success: false`.
