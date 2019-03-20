import ORSSerial

/**
 */
public protocol SerialPortController: class, NSObjectProtocol {
    associatedtype Version: Equatable, Codable, CustomDebugStringConvertible
    
    ///
    var isOpen: Bool { get }
    
    ///
    func detect(_ callback: @escaping (_ version: Version, _ voltage: Voltage) -> ())
    
    /**
     */
    func addOperation<Operation: SerialPacketOperation<Self>>(_ operation: Operation)
    
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

