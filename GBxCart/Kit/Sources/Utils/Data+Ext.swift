import Foundation

extension Data {
    public static func random(_ count: Int) -> Data {
        return Data((0...count).map { _ in
            UInt8.random(in: 0...UInt8.max)
        })
    }
    
    public func hexString(separator: String = " ") -> String {
        return map { String($0, radix: 16, uppercase: true) }.joined(separator: separator)
    }
}
