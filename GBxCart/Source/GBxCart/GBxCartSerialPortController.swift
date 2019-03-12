import ORSSerial
import Gibby

/**
 */
open class GBxCartSerialPortController: NSObject, SerialPortController {
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
            throw ReaderControllerError.failedToOpen(self.reader)
        }
    }
    
    /**
     */
    public final func addOperation(_ operation: Operation) {
        self.queue.addOperation(operation)
    }
}

extension GBxCartSerialPortController {
    public static func reader<Cartridge: Gibby.Cartridge>(for platform: Cartridge.Platform.Type) throws -> GBxCartReaderController<Cartridge> {
        switch platform {
        case is GameboyClassic.Type:
            return try GBxCartClassicReaderController() as! GBxCartReaderController<Cartridge>
        case is GameboyAdvance.Type:
            return try GBxCartAdvanceReaderController() as! GBxCartReaderController<Cartridge>
        default:
            fatalError()
        }
    }
}
