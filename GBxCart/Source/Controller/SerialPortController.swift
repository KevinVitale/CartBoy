import ORSSerial

/**
 */
public protocol SerialPortController: class, NSObjectProtocol {
    ///
    var isOpen: Bool { get }
    
    /**
     */
    @discardableResult
    func close() -> Bool
    
    /**
     */
    func addOperation(_ operation: Operation)
    
    /**
     */
    func openReader(delegate: ORSSerialPortDelegate?) throws
}
