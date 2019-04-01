import ORSSerial
import Gibby

public class InsideGadgetsCartridgeController<Cartridge: Gibby.Cartridge>: ThreadSafeSerialPortController, CartridgeController {
    override init(matching portProfile: ORSSerialPortManager.PortProfile = .prefix("/dev/cu.usbserial-14")) throws {
        try super.init(matching: portProfile)
    }
    
    private let queue: OperationQueue = .init()

    @discardableResult
    override final func send(_ data: Data?, timeout: UInt32? = nil) -> Bool {
        return super.send(data, timeout: timeout)
    }

    public override func open() -> ORSSerialPort {
        return super.open().configuredAsGBxCart()
    }
    
    func add(_ operation: Operation) {
        self.queue.addOperation(operation)
    }
}

extension InsideGadgetsCartridgeController: CartridgeReaderController {
    public static func reader() throws -> InsideGadgetsReader<Cartridge> {
        return .init(controller: try .init())
    }
}

extension InsideGadgetsCartridgeController: CartridgeWriterController where Cartridge: FlashCartridge {
    public static func writer() throws -> InsideGadgetsWriter<Cartridge> {
        return .init(controller: try .init())
    }
}

extension InsideGadgetsCartridgeController {
    @discardableResult
    func go(to address: Cartridge.Platform.AddressSpace, timeout: UInt32 = 250) -> Bool {
        return send("A", number: address, timeout: timeout)
    }
    
    @discardableResult
    func read() -> Bool {
        switch Cartridge.Platform.self {
        case is GameboyClassic.Type:
            return send("R".bytes())
        case is GameboyAdvance.Type:
            return send("r".bytes())
        default:
            return false
        }
    }
    
    @discardableResult
    func `break`(timeout: UInt32 = 0) -> Bool {
        return send("\0".bytes(), timeout: timeout)
    }
    
    @discardableResult
    func stop(timeout: UInt32 = 0) -> Bool {
        return send("0".bytes(), timeout: timeout)
    }
    
    @discardableResult
    func `continue`() -> Bool {
        return send("1".bytes())
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
