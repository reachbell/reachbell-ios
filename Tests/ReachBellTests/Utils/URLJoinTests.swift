import XCTest
@testable import ReachBell

final class URLJoinTests: XCTestCase {
    func testTrailingSlashesAreRemoved() {
        XCTAssertEqual(URLJoin.normalizedBase("https://api.example.test//"), "https://api.example.test")
    }
}
