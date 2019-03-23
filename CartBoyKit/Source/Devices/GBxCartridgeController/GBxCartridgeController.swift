import ORSSerial
import Gibby

/**
 An opaque `GBxSerialPortController` subclass, capable of performing
 platform-specific serial port operations.
 */
public class GBxCartridgeController<Cartridge: Gibby.Cartridge>: ThreadSafeSerialPortController, CartridgeController {
    typealias Intent = SerialPacketOperation<GBxCartridgeController<Cartridge>>.Intent
    
    @discardableResult
    public override final func send(_ data: Data?, timeout: UInt32? = nil) -> Bool {
        defer { usleep(250) }
        return super.send(data, timeout: timeout)
    }

    public override func open() {
        super.open()
        self.reader.configuredAsGBxCart()
    }
    
    @objc public func packetOperation(_ operation: Operation, didBeginWith intent: Any?) {
        guard let intent = intent as? Intent else {
            operation.cancel()
            return
        }
        
        if case .read(_, let context) = intent {
            switch context {
            case .cartridge(let header) where !header.isLogoValid: fallthrough
            case  .saveFile(let header) where !header.isLogoValid: return operation.cancel()
            default: (/* do nothing */)
            }
        }
    }

    @objc public func packetLength(for intent: Any?) -> UInt {
        guard let intent = intent as? Intent else {
            fatalError()
        }
        
        switch intent {
        case .read:
            return 64
        case .write:
            return 1
        }
    }
    
    public func boardInfo(_ callback: @escaping (((Version, Voltage)?) -> ())) {
        whileOpened(perform: { reader -> (Version, Voltage)? in
            let group = DispatchGroup()
            var dataReceived: Data = .init()
            //------------------------------------------------------------------
            reader.send("0\0".data(using: .ascii)!)
            //------------------------------------------------------------------
            // PCB Version
            //------------------------------------------------------------------
            group.enter()
            self.reader.send(ORSSerialRequest(
                dataToSend: "h\0".bytes()!
                , userInfo: nil
                , timeoutInterval: 1
                , responseDescriptor: ORSSerialPacketDescriptor(maximumPacketLength: 1, userInfo: nil) {
                    if let data = $0 {
                        dataReceived.append(data)
                    }
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
                , responseDescriptor: ORSSerialPacketDescriptor(maximumPacketLength: 1, userInfo: nil) {
                    if let data = $0 {
                        dataReceived.append(data)
                    }
                    group.leave()
                    return true
            }))
            //------------------------------------------------------------------
            // Voltage Version
            //------------------------------------------------------------------
            group.enter()
            reader.send(ORSSerialRequest(
                dataToSend: "C\0".bytes()!
                , userInfo: nil
                , timeoutInterval: 5
                , responseDescriptor: ORSSerialPacketDescriptor(maximumPacketLength: 1, userInfo: nil) {
                    if let data = $0 {
                        dataReceived.append(data)
                    }
                    group.leave()
                    return true
            }))
            //------------------------------------------------------------------
            // WAIT
            //------------------------------------------------------------------
            group.wait()
            //------------------------------------------------------------------
            let versionBytes = dataReceived.prefix(upTo: 2)
            guard let minorVersion = versionBytes.first, let firmware = versionBytes.last else {
                return nil
            }
            //------------------------------------------------------------------
            return (.init(minor: Int(minorVersion), revision: String(firmware, radix: 16, uppercase: false)), dataReceived.dropFirst(dataReceived.count).hexString() == "1" ? .high : .low)
        }) { boardInfo in
            DispatchQueue.main.async {
                callback(boardInfo)
            }
        }
    }
}

extension GBxCartridgeController where Cartridge.Platform == GameboyClassic {
    public static func controller() throws -> GBxCartridgeController<Cartridge> {
        return try GBxCartridgeControllerClassic<Cartridge>(matching: .prefix("/dev/cu.usbserial-14"))
    }
}

extension GBxCartridgeController where Cartridge.Platform == GameboyAdvance {
    public static func controller() throws -> GBxCartridgeController<Cartridge> {
        return try GBxCartridgeControllerAdvance<Cartridge>(matching: .prefix("/dev/cu.usbserial-14"))
    }
}

extension GBxCartridgeController {
    public struct Version: CustomStringConvertible {
        fileprivate init(major: Int = 1, minor: Int, revision: String) {
            self.major = major
            self.minor = minor
            self.revision = revision.lowercased()
        }
        
        let major: Int
        let minor: Int
        let revision: String
        
        public var description: String {
            return "v\(major).\(minor)\(revision)"
        }
    }
    
}

extension ORSSerialPort {
    @discardableResult
    fileprivate final func configuredAsGBxCart() -> ORSSerialPort {
        self.allowsNonStandardBaudRates = true
        self.baudRate = 1000000
        self.dtr = true
        self.rts = true
        self.numberOfDataBits = 8
        self.numberOfStopBits = 1
        self.parity = .none
        return self
    }
}
