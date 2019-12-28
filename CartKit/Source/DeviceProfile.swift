import ORSSerial

/**
 Provides a description of vendor-specific `SerialPort`.
 */
public protocol DeviceProfile {
    /// The port profile that identifies the serial port.
    ///
    /// - note: `.usb(vendorID:productID:)` is preferred.
    static var portProfile: ORSSerialPortManager.PortProfile { get }
    
    /**
     Configures a serial port's properties, then returns it.
     
     - parameter serialPort: The `ORSSerialPort` to be configured.
     - returns: The newly modified serial port.
     */
    static func configure(serialPort: ORSSerialPort) -> ORSSerialPort
}
