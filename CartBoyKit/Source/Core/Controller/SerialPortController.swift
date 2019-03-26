import ORSSerial

/**
 This contract implies the receiver is managing an `ORSSerialPort` instance.
 
 A `SerialPortController` instance can:
    - `open` and `close` a serial port; and
    - `send` arbitruary data to said serial port; and
    - execute `SerialPacketOperations` submitted as operations; and
    - detect hardware features, such as board revision and voltage settings.
 */
public protocol SerialPortController {
    ///
    var isOpen: Bool { get }

    /**
     */
    func openReader(delegate: ORSSerialPortDelegate?)
    
    /**
     */
    @discardableResult
    func close() -> Bool
    
    func close(delegate: ORSSerialPortDelegate)

    /**
     */
    @discardableResult
    func send(_ data: Data?, timeout: UInt32?) -> Bool
    
    /**
     */
    @discardableResult
    func send<Number: FixedWidthInteger>(_ command: String, number: Number, radix: Int, terminate: Bool, timeout: UInt32?) -> Bool
}
