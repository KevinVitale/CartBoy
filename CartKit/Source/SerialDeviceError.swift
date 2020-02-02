import Foundation
import Gibby

public enum SerialDeviceError<Platform: Gibby.Platform>: LocalizedError, CustomNSError {
    case platformNotSupported(Platform.Type)
    case underlyingMD5Error
    case mismatchedMD5(computed: String, expected: String)
    
    public var errorDescription: String? {
        switch self {
        case .platformNotSupported(let platform): return NSLocalizedString("\(platform) not supported".capitalized, comment: "")
        case .underlyingMD5Error: return NSLocalizedString("Unknown error occurred while computing MD5 digest", comment: "")
        case .mismatchedMD5(let computed, let expected): return NSLocalizedString("MD5 does not match: \(computed) (expected: \(expected)", comment: "")
        }
    }
    
    public var recoverySuggestion: String? {
        switch self {
        case .mismatchedMD5         :fallthrough
        case .underlyingMD5Error    :fallthrough
        case .platformNotSupported  :return nil
        }
    }
    
    public var errorCode: Int {
        switch self {
        case .platformNotSupported :return 101
        case .underlyingMD5Error   :return 200
        case .mismatchedMD5        :return 201
        }
    }
    
    public static var errorDomain: String {
        return "com.cartboy.controller.cartridge"
    }
}
