import ORSSerial
import Gibby

/**
 Cart reader implementation for insideGadgets.com's 'GBxCart'.
 */
public final class GBxCartReaderController<Cartridge: Gibby.Cartridge>: NSObject, ReaderController {
    public init(matching portProfile: ORSSerialPortManager.PortProfile = .GBxCart) throws {
        self.reader = try ORSSerialPortManager.port(matching: portProfile)
    }
    
    private let reader: ORSSerialPort
    private let queue = OperationQueue()
    
    public var isOpen: Bool {
        return self.reader.isOpen
    }
    
    @discardableResult
    public func closePort() -> Bool {
        return self.reader.close()
    }
    
    public var delegate: ORSSerialPortDelegate? {
        get {
            return reader.delegate
        }
        set {
            reader.delegate = newValue
        }
    }
    
    public func addOperation(_ operation: Operation) {
        self.queue.addOperation(operation)
    }
    
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

    public final func openReader(delegate: ORSSerialPortDelegate?) throws {
        self.reader.delegate = delegate
        
        if self.reader.isOpen == false {
            self.reader.open()
            self.reader.configuredAsGBxCart()
        }

        guard self.reader.isOpen else {
            throw ReaderControllerError.failedToOpen(self.reader)
        }

    }
    
    public func continueReading() {
        let keepReading = "1".data(using: .ascii)!
        self.reader.send(keepReading)
    }
    
    public func stopReading() {
        let stopReading = "0".data(using: .ascii)!
        self.reader.send(stopReading)
    }
    
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
