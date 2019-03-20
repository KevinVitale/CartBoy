import ORSSerial

/**
 This contract implies the receiver is managing an `ORSSerialPort` instance.
 
 A `SerialPortController` instance can:
    - `open` and `close` a serial port; and
    - `send` arbitruary data to said serial port; and
    - execute `SerialPacketOperations` submitted as operations; and
    - detect hardware features, such as board revision and voltage settings.
 */
public protocol SerialPortController: SerialPacketOperationDelegate {
    associatedtype Version: Equatable, Codable, CustomDebugStringConvertible
    
    ///
    var isOpen: Bool { get }
    
    ///
    func detect(_ callback: @escaping ((Version, Voltage)?) -> ())

    /**
     */
    func openReader(delegate: ORSSerialPortDelegate?)
    
    /**
     */
    @discardableResult
    func close() -> Bool

    /**
     */
    @discardableResult
    func send(_ data: Data?) -> Bool
}

extension SerialPortController {
    /**
     Peforms an asychronous `block` operation while the serial port is opened.
     */
    func whileOpened<T>(block: @escaping () -> T?, _ callback: @escaping (T?) -> ()) {
        var operation: OpenPortOperation<Self>! = nil {
            didSet {
                operation.start()
            }
        }
        operation = OpenPortOperation<Self>(controller: self) {
            callback(block())
        }
    }
}
