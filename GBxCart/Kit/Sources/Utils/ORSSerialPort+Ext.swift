import ORSSerial

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
    
    private static func port(matching profile: PortProfile) -> ORSSerialPort? {
        return shared()
            .availablePorts
            .filter(profile.matcher())
            .first
    }
    
    public static func GBxCart(_ profile: PortProfile = .prefix("/dev/cu.usbserial-14")) -> ORSSerialPort? {
        let port = ORSSerialPortManager.port(matching: profile)
        port?.allowsNonStandardBaudRates = true
        port?.baudRate = 1000000
        port?.dtr = true
        port?.rts = true
        port?.numberOfDataBits = 8
        port?.numberOfStopBits = 1
        port?.parity = .none
        return port
    }
}
