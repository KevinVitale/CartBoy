import ORSSerial

extension ORSSerialPortManager {
    public enum PortMatchingError: Error, CustomDebugStringConvertible {
        case noMatching(profile: PortProfile)
        
        public var debugDescription: String {
            switch self {
            case .noMatching(let profile):
                return "No ports found matching \(profile)."
            }
        }
    }
}

extension ORSSerialPortManager {
    public enum PortProfile {
        case prefix(String)

        fileprivate func matcher() -> ((ORSSerialPort) -> Bool) {
            switch self {
            case .prefix(let prefix):
                return { $0.path.hasPrefix(prefix) }
            }
        }
    }
    
    private static func match(_ profile: PortProfile) -> ORSSerialPort? {
        return shared()
            .availablePorts
            .filter(profile.matcher())
            .first
    }
    
    public static func port(matching profile: PortProfile) throws -> ORSSerialPort {
        guard let port = ORSSerialPortManager.match(profile) else {
            throw PortMatchingError.noMatching(profile: profile)
        }
        return port
    }
    
    public static func GBxCart(_ profile: PortProfile = .prefix("/dev/cu.usbserial-14")) throws -> ORSSerialPort {
        let cart = try port(matching: profile)
        cart.allowsNonStandardBaudRates = true
        cart.baudRate = 1000000
        cart.dtr = true
        cart.rts = true
        cart.numberOfDataBits = 8
        cart.numberOfStopBits = 1
        cart.parity = .none
        return cart
    }
}
