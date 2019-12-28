import Foundation
import Gibby

public enum SerialDeviceError<Platform: Gibby.Platform>: LocalizedError, CustomNSError {
    case platformNotSupported(Platform.Type)
    case invalidHeader
    
    public var errorDescription: String? {
        switch self {
        case .platformNotSupported(let platform): return NSLocalizedString("\(platform) not supported".capitalized, comment: "")
        case .invalidHeader: return NSLocalizedString("Invalid Cartridge Header", comment: "")
        }
    }
    
    public var recoverySuggestion: String? {
        switch self {
        case .platformNotSupported: return nil
        case .invalidHeader: return NSLocalizedString("The cartridge's header is either missing or otherwise not valid. Reseat the cartridge in the device and try again.", comment: "")
        }
    }
    
    public var errorCode: Int {
        switch self {
        case .platformNotSupported: return 111
        case .invalidHeader: return 101
        }
    }
    
    public static var errorDomain: String {
        return "com.cartboy.controller.cartridge"
    }
}
