import ORSSerial
import Gibby

public protocol ReaderController: class {
    init(matching portProfile: ORSSerialPortManager.PortProfile) throws
    
    /// The associated platform that the adopter relates to.
    associatedtype Cartridge: Gibby.Cartridge

    /// The cartridge reader that this adopter is controlling.
    var reader: ORSSerialPort  { get }
    var  queue: OperationQueue { get }
    
    /// The number of bytes the controller reads until waiting for a 'continue'.
    static var cacheSize: Int  { get }

    /**
     */
    func openReader(delegate: ORSSerialPortDelegate?) throws

    /**
     */
    func startReading(range: Range<Int>)
    
    /**
     */
    func continueReading()
    
    /**
     */
    func stopReading()
    
    /**
     */
    func set<Header: Gibby.Header>(bank: Int, with header: Header) where Header == Self.Cartridge.Header
}

extension ReaderController {
    /// Default cache size.
    public static var cacheSize: Int {
        return 64
    }
    
    /**
     */
    public func readHeader(result: @escaping ((Self.Cartridge.Header?) -> ())) {
        self.queue.addOperation(ReadHeaderOperation<Self>(controller: self, result: result))
    }
    
    /**
     */
    public func readCartridge(header: Self.Cartridge.Header? = nil, result: @escaping ((Self.Cartridge?) -> ())) {
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

/**
 */
public enum ReaderControllerError: Error {
    case failedToOpen(ORSSerialPort?)
}
