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
    public enum PortProfile: Equatable {
        case prefix(String)
        
        public static func ==(lhs: PortProfile, rhs: PortProfile) -> Bool {
            switch (lhs, rhs) {
            case (.prefix(let lhsPrefix), .prefix(let rhsPrefix)):
                return lhsPrefix == rhsPrefix
            }
        }

        fileprivate func matcher() -> ((ORSSerialPort) -> Bool) {
            switch self {
            case .prefix(let prefix):
                return { $0.path.hasPrefix(prefix) }
            }
        }
        
        public static let GBxCart: PortProfile = .prefix("/dev/cu.usbserial-14")
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
        return try port(matching: profile).configuredAsGBxCart()
    }
}

extension ORSSerialPort {
    @discardableResult
    public final func configuredAsGBxCart() -> ORSSerialPort {
        self.allowsNonStandardBaudRates = true
        self.baudRate = 1000000
        self.dtr = true
        self.rts = true
        self.numberOfDataBits = 8
        self.numberOfStopBits = 1
        self.parity = .none
        return self
    }
}
