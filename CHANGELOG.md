# Changelog

## Unreleased

- `reset()` calls `POST /subscribers/unidentify` for the stored token (best effort) so the user is unlinked on the server at logout. Later registrations, `identify`, `tag` and `untag` wait for it.
- `POST /subscribers` sends `previousToken` when APNs hands out a new token; ReachBell moves the old subscriber's tags and external id to the new token. The last registered token is stored under `com.reachbell.registeredToken` (a token stored by 1.0.0 is treated as registered).
- `reset()` drops the result of an in-flight registration: `onRegistrationResult` is not called and the result is not persisted. `URLSessionTransport` now cancels the data task when the calling task is cancelled.
- Requests send a `User-Agent` (`ReachBell/<ver> (iPhone; CPU iPhone OS <ver> like Mac OS X; <model>) reachbell-ios/<ver>`) and `os`, `osVersion`, `device` fields, so subscribers are recorded as iOS mobile or tablet instead of Unknown / desktop.
- README: use a separate ReachBell project with APNs sandbox on for development builds instead of flipping `sandbox` on the live project.

## 1.0.0

- Initial release.
- `configure(apiKey:apiUrl:)`, `requestAuthorizationAndRegister(options:)`, `setAPNsToken(_:)` with background registration and `onRegistrationResult`.
- `identify(_:)` (stashes the external id until a token exists), `tag(_:)`, `untag(_:)`, `register()`, `reset()`.
- Token and external id persisted in `UserDefaults` with an injectable suite.
- Injectable `ReachBellTransport` for testing.
- `ReachBellError.rejected(reason:)` for 2xx responses with `success: false`.
