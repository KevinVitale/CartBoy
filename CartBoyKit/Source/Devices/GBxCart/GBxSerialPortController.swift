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
    
    /// DEBUG
    public var printStacktrace: Bool = false
    public var printProgress: Bool = false

    ///
    let reader: ORSSerialPort
    
    ///
    public private(set) var version: SerialPortControllerVendorVersion = .init(major: "1", minor: "1", revision: "a")
    
    ///
    public private(set) var voltage: Voltage = .high

    ///
    public var isOpen: Bool {
        return self.reader.isOpen
    }
    
    private final func open() {
        print(NSString(string: #file).lastPathComponent, #function, #line)
        self.reader.open()
    }
    /**
     */
    @discardableResult
    public final func close() -> Bool {
        defer {
            if self.printStacktrace {
                print(#function)
            }
            usleep(2000)
            
            self.isOpenCondition.whileLocked {
                self.delegate = nil
                self.isOpenCondition.signal()
            }
        }
        return self.reader.close()
    }
    
    private let isOpenCondition = NSCondition()
    private var currentDelegate: ORSSerialPortDelegate? = nil // Prevents 'deinit'
    private var delegate: ORSSerialPortDelegate?  {
        get { return reader.delegate     }
        set {
            currentDelegate = newValue
            reader.delegate = newValue
        }
    }

    /**
     */
    public final func openReader(delegate: ORSSerialPortDelegate?) {
        self.isOpenCondition.whileLocked {
            while self.currentDelegate != nil {
                print(NSString(string: #file).lastPathComponent, #function, #line, "Waiting...")
                self.isOpenCondition.wait()
            }
            
            print("Continuing...")
            self.delegate = delegate
            //------------------------------------------------------------------
            DispatchQueue.main.async {
                if self.reader.isOpen == false {
                    self.open()
                    self.reader.configuredAsGBxCart()
                }
            }
        }
    }
    
    /**
     */
    public final func addOperation(_ operation: Operation) {
        operation.start()
    }
}

public enum OperationContext {
    case header
    case cartridge
    case saveFile
}

extension GBxSerialPortController: SerialPacketOperationDelegate {
    public func packetOperation(_ operation: Operation, didBeginWith intent: Any?) {
        guard let intent = intent as? PacketIntent, case .read(_, let context?) = intent, context is OperationContext else {
            operation.cancel()
            return
        }
        
        switch context as! OperationContext {
        case .header:
            self.reader.send("\0A100\0".data(using: .ascii)!)
            self.reader.send("R".data(using: .ascii)!)
        case .cartridge:
            self.reader.send("\0A0\0".data(using: .ascii)!)
            self.reader.send("R".data(using: .ascii)!)
        default:
            fatalError()
        }
    }
    
    public func packetOperation(_ operation: Operation, didUpdate progress: Progress, with intent: Any?) {
        guard let intent = intent as? PacketIntent, case .read(_, let context?) = intent, context is OperationContext else {
            operation.cancel()
            return
        }
        
        self.reader.send("1".data(using: .ascii)!)
    }
    
    public func packetOperation(_ operation: Operation, didComplete buffer: Data, with intent: Any?) {
        guard let intent = intent as? PacketIntent, case .read(_, let context?) = intent, context is OperationContext else {
            operation.cancel()
            return
        }
    }
    
    public func packetLength(for intent: Any?) -> UInt {
        guard let intent = intent as? PacketIntent else {
            fatalError()
        }
        
        switch intent {
        case .read:
            return 64
        case .write:
            return 1
        }
    }
}

extension GBxSerialPortController {
    public static func controller<Cartridge: Gibby.Cartridge>(for cartrige: Cartridge.Type) throws -> GBxCartridgeController<Cartridge> where Cartridge.Platform == GameboyClassic {
        return try GBxCartridgeControllerClassic<Cartridge>()
    }
    
    public static func controller<Cartridge: Gibby.Cartridge>(for cartrige: Cartridge.Type) throws -> GBxCartridgeController<Cartridge> where Cartridge.Platform == GameboyAdvance {
        return try GBxCartridgeControllerAdvance<Cartridge>()
    }
}
