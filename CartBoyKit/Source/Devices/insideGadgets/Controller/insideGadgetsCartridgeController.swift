import ORSSerial
import Gibby

public class InsideGadgetsCartridgeController<Cartridge: Gibby.Cartridge>: ThreadSafeSerialPortController, CartridgeController {
    fileprivate override init(matching portProfile: ORSSerialPortManager.PortProfile = .prefix("/dev/cu.usbserial-14")) throws {
        try super.init(matching: portProfile)
    }

    @discardableResult
    override final func send(_ data: Data?, timeout: UInt32? = nil) -> Bool {
        defer { usleep(250) }
        return super.send(data, timeout: timeout)
    }

    public override func open() -> ORSSerialPort {
        return super.open().configuredAsGBxCart()
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
