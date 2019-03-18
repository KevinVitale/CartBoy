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
    private let queue = OperationQueue()
    
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
    public final func close(wait timeout: UInt32 = 2000) -> Bool {
        defer {
            if self.printStacktrace {
                print(#function)
            }
            usleep(timeout)
        }
        return self.reader.close()
    }
    
    /**
     */
    public final func openReader(delegate: ORSSerialPortDelegate?) throws {
        DispatchQueue.main.async {
            self.reader.delegate = delegate
            
            if self.reader.isOpen == false {
                self.open()
                self.reader.configuredAsGBxCart()
                
                /*
                 self.version.change(minor: self.sendAndWait(command: "h")) // PCB
                 self.version.change(revision: self.sendAndWait(command: "V")) // Firmware
                 self.voltage = self.sendAndWait(command: "C") == "1" ? .high : .low
                 */
            }
            
            /*
            guard self.reader.isOpen else {
                throw SerialPortControllerError.failedToOpen(self.reader)
            }
             */
        }
    }
    
    /**
     */
    public final func addOperation(_ operation: Operation) {
        self.queue.addOperation(operation)
    }
    
    /**
     */
    private func sendAndWait(data: Data) -> String {
        let group = DispatchGroup()
        group.enter()
        //----------------------------------------------------------------------
        var version = ""
        let responseDescriptor = ORSSerialPacketDescriptor(maximumPacketLength: 1, userInfo: nil) { data in
            defer { group.leave() }
            version = data?.hexString().lowercased() ?? ""
            return true
        }
        let serialRequest = ORSSerialRequest(
            dataToSend: data
            , userInfo: nil
            , timeoutInterval: 5
            , responseDescriptor: responseDescriptor
        )
        //----------------------------------------------------------------------
        self.reader.send(serialRequest)
        //----------------------------------------------------------------------
        group.wait()
        return version
    }
    
    /**
     */
    func sendAndWait(command: String) -> String {
        return self.sendAndWait(data: command.data(using: .ascii)!)
    }
    
    /**
     */
    func sendAndWait(value: Int, radix: Int = 16) -> String {
        return self.sendAndWait(data: String(value, radix: radix, uppercase: false).data(using: .ascii)!)
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
