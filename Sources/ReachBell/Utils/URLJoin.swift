import Foundation

enum URLJoin {
    static func normalizedBase(_ apiUrl: String) -> String {
        var base = apiUrl.trimmingCharacters(in: .whitespacesAndNewlines)
        while base.hasSuffix("/") {
            base.removeLast()
        }
        return base
    }

    static func url(base: String, path: String) -> URL? {
        URL(string: base + path)
    }
}
