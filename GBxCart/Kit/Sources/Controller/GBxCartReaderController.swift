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
}
