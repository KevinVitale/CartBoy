import ORSSerial
import Gibby

public protocol ReaderController: class {
    init(matching portProfile: ORSSerialPortManager.PortProfile) throws
    
    /// The associated platform that the adopter relates to.
    associatedtype Platform: Gibby.Platform

    /// The cartridge reader that this adopter is controlling.
    var reader: ORSSerialPort  { get }
    var  queue: OperationQueue { get }
    
    /// The number of bytes the controller reads until waiting for a 'continue'.
    static var cacheSize: Int  { get }

    /**
     */
    func openReader(delegate: ORSSerialPortDelegate?) throws

    func sendContinueReading()
    func sendHaltReading()

    /**
     */
    func readHeaderStrategy() -> (ReadHeaderOperation<Self>) -> ()

    /**
     */
    func readCartridgeStrategy() -> (ReadCartridgeOperation<Self>) -> ()
}

extension ReaderController {
    /// Default cache size.
    public static var cacheSize: Int {
        return 64
    }
    
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
