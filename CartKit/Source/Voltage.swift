import Gibby

public enum Voltage: String, CustomDebugStringConvertible {
    case high    = "5V"    // 5V
    case low     = "3.3V"  // 3_3V

    init?(_ byte: UInt8) {
        switch byte {
        case 1:  self = .high
        case 2:  self = .low
        default: return nil
        }
    }

    public var debugDescription: String {
        return self.rawValue
    }
    
    var bytes: Data? {
        (self == .low ? "3" : "5").bytes()
    }
}

public enum VoltageError: Error {
    case invalidVoltage
}

public enum VoltageCheckError<Platform: Gibby.Platform>: Error {
    case voltageMismatch(expected: Platform.Type)
}
