import XCTest
@testable import ReachBell

final class DataHexTests: XCTestCase {
    func testLowercaseHex() {
        let data = Data([0x00, 0x0f, 0xab, 0xff, 0x10, 0x9c])
        XCTAssertEqual(data.lowercaseHexString, "000fabff109c")
    }

    func testEmpty() {
        XCTAssertEqual(Data().lowercaseHexString, "")
    }
}
