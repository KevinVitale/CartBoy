import ORSSerial
import Gibby


/**
 An opaque `GBxSerialPortController` subclass, capable of performing
 platform-specific serial port operations.
 */
public class GBxCartridgeController<Cartridge: Gibby.Cartridge>: ThreadSafeSerialPortController, CartridgeController {
    public override func open() {
        super.open()
        self.reader.configuredAsGBxCart()
    }
    
    @objc public func packetOperation(_ operation: Operation, didBeginWith intent: Any?) {
        guard let intent = intent as? Intent<GBxCartridgeController<Cartridge>> else {
            operation.cancel()
            return
        }
        
        if case .read(_, let context) = intent {
            switch context {
            case .cartridge(let header) where !header.isLogoValid: fallthrough
            case  .saveFile(let header) where !header.isLogoValid:
                operation.cancel()
                return
            default: (/* do nothing */)
            }
        }
    }

    @objc public func packetLength(for intent: Any?) -> UInt {
        guard let intent = intent as? Intent<GBxCartridgeController<Cartridge>> else {
            fatalError()
        }
        
        switch intent {
        case .read:
            return 64
        case .write:
            return 1
        }
    }
    
    public override func version(_ callback: @escaping ((String?) -> ())) {
        whileOpened(perform: {
            let group = DispatchGroup()
            var dataReceived: Data = .init()
            //------------------------------------------------------------------
            self.send("0".bytes())
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
            // WAIT
            //------------------------------------------------------------------
            group.wait()
            //------------------------------------------------------------------
            return dataReceived
        }) { data in
            guard let data = data else {
                callback(nil)
                return
            }
            
            callback("\("v1.\(data.hexString(separator: ""))".lowercased())")
        }
    }
    
    public override func voltage(_ callback: @escaping ((Voltage?) -> ())) {
        whileOpened(perform: {
            let group = DispatchGroup()
            var dataReceived: Data = .init()
            //------------------------------------------------------------------
            self.send("0".bytes())
            //------------------------------------------------------------------
            // Voltage Version
            //------------------------------------------------------------------
            group.enter()
            self.reader.send(ORSSerialRequest(
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
            return dataReceived
        }) { data in
            guard let data = data else {
                callback(nil)
                return
            }
            
            callback(data.hexString() == "1" ? .high : .low)
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
    enum Timeout: UInt32 {
        case veryShort = 100
        case short     = 250
        case medium    = 1000
        case long      = 5000
        case veryLong  = 10000
    }
    
    final func timeout(_ timeout: Timeout = .short) {
        usleep(timeout.rawValue)
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
