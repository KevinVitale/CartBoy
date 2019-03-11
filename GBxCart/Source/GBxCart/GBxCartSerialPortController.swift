import ORSSerial
import Gibby

/**
 */
open class GBxCartSerialPortController: NSObject, SerialPortController {
    /**
     */
    public required init(matching portProfile: ORSSerialPortManager.PortProfile = .GBxCart) throws {
        self.reader = try ORSSerialPortManager.port(matching: portProfile)
    }
    
    
    ///
    private let reader: ORSSerialPort
    
    ///
    private let queue = OperationQueue()
    
    ///
    public var isOpen: Bool {
        return self.reader.isOpen
    }
    
    /**
     */
    @discardableResult
    final func close() -> Bool {
        defer {
            usleep(2000)
        }
        return self.reader.close()
    }
    
    /**
     */
    final func openReader(delegate: ORSSerialPortDelegate?) throws {
        self.reader.delegate = delegate
        
        if self.reader.isOpen == false {
            self.reader.open()
            self.reader.configuredAsGBxCart()
        }
        
        guard self.reader.isOpen else {
            throw ReaderControllerError.failedToOpen(self.reader)
        }
    }
    
    /**
     */
    final func addOperation(_ operation: Operation) {
        self.queue.addOperation(operation)
    }
    
}
