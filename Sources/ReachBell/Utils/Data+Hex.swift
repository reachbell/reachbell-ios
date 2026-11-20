import Foundation

extension Data {
    var lowercaseHexString: String {
        let digits = Array("0123456789abcdef".utf8)
        var bytes = [UInt8]()
        bytes.reserveCapacity(count * 2)
        for byte in self {
            bytes.append(digits[Int(byte >> 4)])
            bytes.append(digits[Int(byte & 0x0f)])
        }
        return String(decoding: bytes, as: UTF8.self)
    }
}
