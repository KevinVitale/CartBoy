import ORSSerial
import Gibby

public final class GBxCartReaderController<Platform: Gibby.Platform>: NSObject, ReaderController {
    public init(matching portProfile: ORSSerialPortManager.PortProfile = .GBxCart) throws {
        self.reader = try ORSSerialPortManager
            .port(matching: portProfile)
            .configuredAsGBxCart()
    }
    
    public let reader: ORSSerialPort
    public let queue = OperationQueue()

    public final func openReader(delegate: ORSSerialPortDelegate?) throws {
        self.reader.delegate = delegate
        
        if reader.isOpen == false {
            self.reader.open()
        }

        guard self.reader.isOpen else {
            throw ReaderControllerError.failedToOpen(self.reader)
        }

    }
    
    public func sendStopBreak() {
        self.reader.send("0\0".data(using: .ascii)!)
    }
    
    public func sendBeginReading() {
        switch Platform.self {
        case is GameboyClassic.Type:
            self.reader.send("R".data(using: .ascii)!)
        case is GameboyAdvance.Type:
            self.reader.send("r".data(using: .ascii)!)
        default: ()
        }
    }

    public func sendContinueReading() {
        self.reader.send("1".data(using: .ascii)!)
    }

    public func sendGo(to address: Platform.AddressSpace) {
        switch Platform.self {
        case is GameboyClassic.Type:
            self.reader.send("A\(String(address, radix: 16, uppercase: true))\0".data(using: .ascii)!)
        case is GameboyAdvance.Type: ()
        default: ()
        }
    }
    
    public func sendSwitch(bank: Platform.AddressSpace, at address: Platform.AddressSpace) {
        switch Platform.self {
        case is GameboyClassic.Type:
            self.reader.send("B\(String(address, radix: 16, uppercase: true))\0".data(using: .ascii)!)
            self.reader.send("B\(String(bank, radix: 16, uppercase: true))\0".data(using: .ascii)!)
        case is GameboyAdvance.Type: ()
        default: ()
        }
    }
}
