import ORSSerial

extension ORSSerialPortManager {
    static func port(matching prefix: String) -> ORSSerialPort? {
        return shared()
            .availablePorts
            .filter({ $0.path.hasPrefix(prefix) })
            .first
    }
    
    public static func GBxCart() -> ORSSerialPort? {
        let port = ORSSerialPortManager.port(matching: "/dev/cu.usbserial-14")
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
