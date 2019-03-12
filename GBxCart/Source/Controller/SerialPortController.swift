import ORSSerial

/**
 */
public protocol SerialPortController: class, NSObjectProtocol {
    /**
     */
    init(matching portProfile: ORSSerialPortManager.PortProfile) throws
    
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
