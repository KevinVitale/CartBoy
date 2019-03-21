import Gibby

public protocol FlashCart: Cartridge {
    var capacity: Capacity<Self> { get }
}

extension FlashCart {
    public var hasSufficentCapacity: Bool {
        return count <= capacity.rawValue
    }
}

public enum Capacity<Cart: FlashCart>: RawRepresentable, CustomDebugStringConvertible {
    public init(rawValue: Int) {
        switch rawValue {
        case 0x200000:  self = .two_MB
        default:        self = .unknown(rawValue: rawValue)
        }
    }
    
    public var rawValue: Int {
        switch self {
        case .two_MB: return 0x200000
        case .unknown(let rawValue):
            return rawValue
        }
    }
    
    public var debugDescription: String {
        return ""
    }
    
    case two_MB
    case unknown(rawValue: Int)
}
