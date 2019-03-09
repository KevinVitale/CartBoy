import ORSSerial
import Gibby

/**
 Cart reader implementation for insideGadgets.com's 'GBxCart'.
 */
public final class GBxCartReaderController<Cartridge: Gibby.Cartridge>: NSObject, ReaderController {
    /**
     Creates a new instance of the _GBxCart_ controller for the given `Platform`.
     
     The expected hardware must be connected prior to attempting to instantiate
     an instance, or an exception is thrown.
     
     - parameters:
        - portProfile:  The profile which describes the port that the 'GBxCart' hardware
                        is expected to be connected to.
    
     - note: See `ORSSerialPortManager.PortProfile` for potential `portProfile` values.
     */
    public init(matching portProfile: ORSSerialPortManager.PortProfile = .GBxCart) throws {
        self.reader = try ORSSerialPortManager.port(matching: portProfile)
    }
    
    

    /// The reader (e.g., _hardware/serial port_).
    public let reader: ORSSerialPort
    
    /// The operation queue upon which the receiever execute submitted requests.
    public let queue = OperationQueue()
    
    /**
     */
    public func startReading(range: Range<Int>) {
        let addrBase16  = String(range.lowerBound, radix: 16, uppercase: true)
        var command     = "\0A\(addrBase16)\0"
        
        switch Cartridge.Platform.self {
        case is GameboyClassic.Type:
            command += "R"
        case is GameboyAdvance.Type:
            command += "r"
        default:
            fatalError("No 'read' strategy provided for \(Cartridge.Platform.self)")
        }
        
        let dataToSend = command.data(using: .ascii)!
        self.reader.send(dataToSend)
    }

    /**
     Opens the reader, optionally assigning its delegate.
     - parameters:
         - delegate: The `reader`'s delegate.
     -
     */
    public final func openReader(delegate: ORSSerialPortDelegate?) throws {
        self.reader.delegate = delegate
        
        if reader.isOpen == false {
            self.reader.open()
            self.reader.configuredAsGBxCart()
        }

        guard self.reader.isOpen else {
            throw ReaderControllerError.failedToOpen(self.reader)
        }

    }
    
    /**
     */
    public func continueReading() {
        let keepReading = "1".data(using: .ascii)!
        self.reader.send(keepReading)
    }
    
    /**
     */
    public func stopReading() {
        let stopReading = "0".data(using: .ascii)!
        self.reader.send(stopReading)
    }
    
    /**
     */
    public func set<Header>(bank: Int, with header: Header) where Header == Cartridge.Header {
        func classic(bank: Int, address: Cartridge.Platform.AddressSpace) {
            let bankAddr    = String(address, radix: 16, uppercase: true)
            let addrDataStr = "B\(bankAddr)\0"
            let addrData    = addrDataStr.data(using: .ascii)!
            self.reader.send(addrData)
            
            // DO NOT DELETE THIS!
            // Bank switch *will not* work if removed.
            usleep(250)
            
            let bankNumr    = String(bank, radix: 10, uppercase: true)
            let bankDataStr = "B\(bankNumr)\0"
            let bankData    = bankDataStr.data(using: .ascii)!
            self.reader.send(bankData)
        }

        func advance() {
        }
        
        switch Cartridge.Platform.self {
        case is GameboyClassic.Type:
            let header = header as! GameboyClassic.Cartridge.Header
            if case .one = header.configuration {
                classic(bank:           0, address: 0x6000)
                classic(bank:   bank >> 5, address: 0x4000)
                classic(bank: bank & 0x1F, address: 0x2000)
            }
            else {
                classic(bank: bank, address: 0x2100)
                if bank >= 0x100 {
                    classic(bank: 1, address: 0x2100)
                }
            }
        case is GameboyAdvance.Type:
            advance()
        default:
            fatalError("No 'read' strategy provided for \(Cartridge.Platform.self)")
        }
    }
}
