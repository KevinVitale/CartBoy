import ORSSerial
import Gibby

public final class GBxCartReaderController<Platform: Gibby.Platform>: NSObject, ReaderController {
    public private(set) var reader: ORSSerialPort!
    public let queue = OperationQueue()

    public typealias Header = Platform.Cartridge.Header

    public final func openReader(matching profile: ORSSerialPortManager.PortProfile) throws {
        guard reader == nil else {
            return
        }
        
        self.reader = try ORSSerialPortManager.port(matching: profile)
        self.reader.open()
        guard self.reader.isOpen else {
            throw ReaderControllerError.failedToOpen(self.reader)
        }

        switch profile {
        case .GBxCart:
            self.reader = self.reader.configuredAsGBxCart()
        default: ()
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
    
    public func sendSwitch(bank: Platform.AddressSpace) {
    }
}
