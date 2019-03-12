import ORSSerial
import Gibby

/**
 */
open class GBxSerialPortController: NSObject, SerialPortController {
    /**
     */
    init(matching portProfile: ORSSerialPortManager.PortProfile = .GBxCart) throws {
        self.reader = try ORSSerialPortManager.port(matching: portProfile)
    }
    
    ///
    let reader: ORSSerialPort
    
    ///
    private let queue = OperationQueue()
    
    ///
    public var isOpen: Bool {
        return self.reader.isOpen
    }
    
    /**
     */
    @discardableResult
    public final func close() -> Bool {
        defer {
            usleep(2000)
        }
        return self.reader.close()
    }
    
    /**
     */
    public final func openReader(delegate: ORSSerialPortDelegate?) throws {
        self.reader.delegate = delegate
        
        if self.reader.isOpen == false {
            self.reader.open()
            self.reader.configuredAsGBxCart()
        }
        
        guard self.reader.isOpen else {
            throw SerialPortControllerError.failedToOpen(self.reader)
        }
    }
    
    /**
     */
    public final func addOperation(_ operation: Operation) {
        self.queue.addOperation(operation)
    }
}

extension GBxSerialPortController {
    public static func controller<Cartridge: Gibby.Cartridge>(for platform: Cartridge.Platform.Type) throws -> GBxCartridgeController<Cartridge> {
        switch platform {
        case is GameboyClassic.Type:
            return try GBxCartridgeControllerClassic() as! GBxCartridgeController<Cartridge>
        case is GameboyAdvance.Type:
            return try GBxCartridgeControllerAdvance() as! GBxCartridgeController<Cartridge>
        default:
            fatalError()
        }
    }
}
