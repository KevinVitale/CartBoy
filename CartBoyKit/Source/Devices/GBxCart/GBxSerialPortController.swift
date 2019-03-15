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
    public private(set) var version: SerialPortControllerVendorVersion = .init(major: "1", minor: "#", revision: "#")
    
    ///
    public private(set) var voltage: Voltage = .high

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
            if self.printStacktrace {
                print(#function)
            }
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
            self.version.change(minor: self.readDevice(property: "h")) // PCB
            self.version.change(revision: self.readDevice(property: "V")) // Firmware
            self.voltage = self.readDevice(property: "C") == "1" ? .high : .low
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
    
    /**
     */
    private func readDevice(property command: String) -> String {
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
            dataToSend: command.data(using: .ascii)!
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
}

extension GBxSerialPortController {
    public static func controller<Cartridge: Gibby.Cartridge>(for cartrige: Cartridge.Type) throws -> GBxCartridgeController<Cartridge> where Cartridge.Platform == GameboyClassic {
        return try GBxCartridgeControllerClassic<Cartridge>()
    }
    
    public static func controller<Cartridge: Gibby.Cartridge>(for cartrige: Cartridge.Type) throws -> GBxCartridgeController<Cartridge> where Cartridge.Platform == GameboyAdvance {
        return try GBxCartridgeControllerAdvance<Cartridge>()
    }
}
