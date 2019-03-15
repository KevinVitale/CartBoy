import Gibby

public protocol FlashCart: Cartridge {
    var  voltage: Voltage        { get }
    var capacity: Capacity<Self> { get }
    
    static func prepare<Controller>(forWritingTo: Controller) -> Bool where Controller: CartridgeController, Controller.Cartridge == Self
}

extension FlashCart {
    public var hasSufficentCapacity: Bool {
        return count <= capacity.rawValue
    }
}

public enum Capacity<Cart: FlashCart>: RawRepresentable, CustomDebugStringConvertible {
    public init(rawValue: Int) {
        switch rawValue {
        case 0x200000:
            self = .two_MB
        default:
            self = .unknown(rawValue: rawValue)
        }
    }
    
    public var rawValue: Int {
        switch self {
        case .two_MB:
            return 0x200000
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

public enum Voltage: String, CustomDebugStringConvertible {
    case high = "5V"    // 5V
    case low  = "3.3V"  // 3_3V
    
    public var debugDescription: String {
        return self.rawValue
    }
}
