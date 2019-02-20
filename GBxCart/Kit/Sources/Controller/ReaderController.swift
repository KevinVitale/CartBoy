import ORSSerial
import Gibby

public protocol ReaderController: class {
    /// The associated platform that the adopter relates to.
    associatedtype Platform: Gibby.Platform
    
    init(matching portProfile: ORSSerialPortManager.PortProfile) throws
    
    /// The cartridge reader that this adopter is controlling.
    var reader: ORSSerialPort  { get }
    var  queue: OperationQueue { get }

    /**
     Locate a serial port matching `profile`, and then attempt to open it.
     
     - parameters:
        - profile: The profile to match against.
     */
    func openReader(delegate: ORSSerialPortDelegate?) throws

    func sendBeginReading()
    func sendContinueReading()
    func sendGo(to address: Platform.AddressSpace)
    func sendStopBreak()
    func sendSwitch(bank: Platform.AddressSpace, at address: Platform.AddressSpace)
}

extension ReaderController {
    public func readHeader(result: @escaping ((Self.Platform.Cartridge.Header?) -> ())) {
        self.queue.addOperation(ReadHeaderOperation<Self>(controller: self, result: result))
    }
    
    public func readCartridge(header: Self.Platform.Cartridge.Header? = nil, result: @escaping ((Self.Platform.Cartridge?) -> ())) {
        if let header = header {
            self.queue.addOperation(ReadCartridgeOperation<Self>(controller: self, header: header, result: result))
        }
        else {
            self.readHeader {
                self.readCartridge(header: $0, result: result)
            }
        }
    }
}

public enum ReaderControllerError: Error {
    case failedToOpen(ORSSerialPort?)
}
