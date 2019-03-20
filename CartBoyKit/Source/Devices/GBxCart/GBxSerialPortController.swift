import ORSSerial
import Gibby

/**
 */
open class GBxSerialPortController: NSObject, SerialPortController, SerialPacketOperationDelegate {
    /**
     */
    public struct Version: Equatable, Codable, CustomDebugStringConvertible {
        public let major: String
        public let minor: String
        public let revision: String
        
        public var debugDescription: String {
            return "v\(major).\(minor)\(revision)"
        }
        
        fileprivate mutating func change(major value: String) {
            self = .init(major: value, minor: minor, revision: revision)
        }
        
        fileprivate mutating func change(minor value: String) {
            self = .init(major: major, minor: value, revision: revision)
        }
        
        fileprivate mutating func change(revision value: String) {
            self = .init(major: major, minor: minor, revision: value)
        }
    }
    
    /**
     */
    required public init(matching portProfile: ORSSerialPortManager.PortProfile = .GBxCart) throws {
        self.reader = try ORSSerialPortManager.port(matching: portProfile)
        super.init()
    }
    
    ///
    final let reader: ORSSerialPort
    
    ///
    func perform<T>(block: @escaping () -> T?, _ callback: @escaping (T?) -> ()) {
        var operation: OpenPortOperation<GBxSerialPortController>! = nil {
            didSet {
                operation.start()
            }
        }
        operation = OpenPortOperation(controller: self) {
            callback(block())
        }
    }
    public func detect(_ callback: @escaping ((Version, Voltage)?) -> ()) {
        self.perform(block: { () -> ((Version, Voltage)) in
            var version = Version(major: "1", minor: "", revision: "")
            let group = DispatchGroup()
            //------------------------------------------------------------------
            // STOP
            //------------------------------------------------------------------
            self.send("0".bytes())
            //------------------------------------------------------------------
            // PCB Version
            //------------------------------------------------------------------
            group.enter()
            self.reader.send(ORSSerialRequest(
                dataToSend: "h\0".bytes()!
                , userInfo: nil
                , timeoutInterval: 5
                , responseDescriptor: ORSSerialPacketDescriptor(maximumPacketLength: 3, userInfo: nil) {
                    version.change(minor: $0!.hexString().lowercased())
                    group.leave()
                    return true
            }))
            //------------------------------------------------------------------
            // Firmware Version
            //------------------------------------------------------------------
            group.enter()
            self.reader.send(ORSSerialRequest(
                dataToSend: "V\0".bytes()!
                , userInfo: nil
                , timeoutInterval: 5
                , responseDescriptor: ORSSerialPacketDescriptor(maximumPacketLength: 3, userInfo: nil) {
                    version.change(revision: $0!.hexString().lowercased())
                    group.leave()
                    return true
            }))
            //------------------------------------------------------------------
            // Voltage Version
            //------------------------------------------------------------------
            var voltage: Voltage = .high
            group.enter()
            self.reader.send(ORSSerialRequest(
                dataToSend: "C\0".bytes()!
                , userInfo: nil
                , timeoutInterval: 5
                , responseDescriptor: ORSSerialPacketDescriptor(maximumPacketLength: 3, userInfo: nil) {
                    voltage = ($0!.hexString() == "1") ? .high : .low
                    group.leave()
                    return true
            }))
            //------------------------------------------------------------------
            // WAIT
            //------------------------------------------------------------------
            group.wait()
            //------------------------------------------------------------------
            // CALLBACK
            //------------------------------------------------------------------
            return (version, voltage)
        }, callback)
    }

    ///
    public var isOpen: Bool {
        return self.reader.isOpen
    }
    
    private final func open() {
        self.reader.open()
    }
    /**
     */
    @discardableResult
    public final func close() -> Bool {
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
                self.isOpenCondition.wait()
            }
            
            // print("Continuing...")
            self.delegate = delegate
            //------------------------------------------------------------------
            DispatchQueue.main.sync {
                if self.reader.isOpen == false {
                    self.open()
                    self.reader.configuredAsGBxCart()
                }
            }
        }
    }
    
    /**
     */
    @objc public func packetOperation(_ operation: Operation, didComplete intent: Any?) {
        self.isOpenCondition.whileLocked {
            self.delegate = nil
            self.isOpenCondition.signal()
        }
    }
    
    /**
     */
    @discardableResult
    public final func send(_ data: Data?) -> Bool {
        guard let data = data else {
            return false
        }
        return self.reader.send(data)
    }
}

extension GBxSerialPortController {
    enum Timeout: UInt32 {
        case short    = 250
        case medium   = 1000
        case long     = 5000
        case veryLong = 10000
    }
    
    final func timeout(_ timeout: Timeout = .short) {
        usleep(timeout.rawValue)
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
