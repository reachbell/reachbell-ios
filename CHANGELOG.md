# Changelog

## 1.0.0

- Initial release.
- `configure(apiKey:apiUrl:)`, `requestAuthorizationAndRegister(options:)`, `setAPNsToken(_:)` with background registration and `onRegistrationResult`.
- `identify(_:)` (stashes the external id until a token exists), `tag(_:)`, `untag(_:)`, `register()`, `reset()`.
- Token and external id persisted in `UserDefaults` with an injectable suite.
- Injectable `ReachBellTransport` for testing.
- `ReachBellError.rejected(reason:)` for 2xx responses with `success: false`.
