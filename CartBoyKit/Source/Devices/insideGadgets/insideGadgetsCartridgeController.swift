import ORSSerial
import Gibby

public protocol CartridgeController: ThreadSafeSerialPortController {
    associatedtype Cartridge: Gibby.Cartridge
}

public protocol CartridgeReaderController: CartridgeController {
    associatedtype Cartridge
    associatedtype Reader: CartridgeReader where Reader.Cartridge == Self.Cartridge
    
    static func reader() throws -> Reader
}

public protocol CartridgeWriterController: CartridgeController {
    associatedtype Cartridge
    associatedtype Writer: CartridgeWriter where Writer.FlashCartridge == Self.Cartridge
    
    static func writer() throws -> Writer
}

public class InsideGadgetsCartridgeController<Cartridge: Gibby.Cartridge>: ThreadSafeSerialPortController, CartridgeController {
    @discardableResult
    public override final func send(_ data: Data?, timeout: UInt32? = nil) -> Bool {
        defer { usleep(250) }
        return super.send(data, timeout: timeout)
    }

    public override func open() -> ORSSerialPort {
        return super.open().configuredAsGBxCart()
    }
}

extension InsideGadgetsCartridgeController: CartridgeReaderController {
    fileprivate static func controller<Cartridge: Gibby.Cartridge>() throws -> InsideGadgetsCartridgeController<Cartridge> {
        return try InsideGadgetsCartridgeController<Cartridge>(matching: .prefix("/dev/cu.usbserial-14"))
    }
    
    public static func reader() throws -> InsideGadgetsReader<Cartridge> {
        return .init(controller: try controller())
    }
}

extension InsideGadgetsCartridgeController: CartridgeWriterController where Cartridge: FlashCartridge {
    public static func writer() throws -> InsideGadgetsWriter<Cartridge> {
        return .init(controller: try controller())
    }
}

extension InsideGadgetsCartridgeController {
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
