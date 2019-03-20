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
}
