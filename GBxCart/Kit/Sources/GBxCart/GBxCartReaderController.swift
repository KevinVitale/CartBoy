import ORSSerial
import Gibby

public final class GBxCartReaderController<Platform: Gibby.Platform>: NSObject, ReaderController {
    public init(matching portProfile: ORSSerialPortManager.PortProfile = .GBxCart) throws {
        self.reader = try ORSSerialPortManager.port(matching: portProfile)
    }
    
    public let reader: ORSSerialPort
    public let queue = OperationQueue()

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
    
    public func sendBeginReading() {
        GBxCartCommand.send(to: self, commands: .read)
    }

    public func sendContinueReading() {
        GBxCartCommand.send(to: self, commands: .proceed)
    }
    
    public func sendHaltReading() {
        GBxCartCommand.send(to: self, commands: .halt)
    }

    public func sendGo(to address: Platform.AddressSpace) {
        GBxCartCommand.send(to: self, commands: .goto(address: address))
    }
    
    public func sendSwitch(bank: Platform.AddressSpace, at address: Platform.AddressSpace) {
        GBxCartCommand.send(to: self, commands: .bank(address: address), .set(bank: bank))
    }
    
    public func readCartridgeStrategy() -> (ReadCartridgeOperation<GBxCartReaderController<Platform>>) -> () {
        switch Platform.self {
        case is GameboyClassic.Type:
            return GBxCartCartridgeReadStrategy.classic as! (ReadCartridgeOperation<GBxCartReaderController<Platform>>) -> ()
        case is GameboyAdvance.Type:
            return GBxCartCartridgeReadStrategy.advance as! (ReadCartridgeOperation<GBxCartReaderController<Platform>>) -> ()
        default: return { _ in
            fatalError("No 'read' strategy provided for \(Platform.self)")
            }
        }
    }
}

fileprivate enum GBxCartCartridgeReadStrategy {
    fileprivate static func classic(_ operation: ReadCartridgeOperation<GBxCartReaderController<GameboyClassic>>) {
        operation.controller.sendHaltReading()
        
        // Enumerate the each bank-switch, reading memory from it.
        for currentBank in 1..<GameboyClassic.AddressSpace(operation.header.romBanks) {
            print("Bank: \(currentBank)")
            
            /**
             The first bank reads 32KB, and 16KB thereafter (`bankBytesToRead`).
             A starting address is also determined. For the bank being read:
                 - Bank #1 starts reading at '0'; or,
                 - Bank #2 and above starts reading at byte '16384' (0x4000).
             */
            operation.bankBytesToRead = currentBank > 1 ? 0x4000 : 0x8000

            if case .one = operation.header.configuration {
                operation.controller.sendSwitch(bank: 0, at: 0x6000)
                operation.controller.sendSwitch(bank: GameboyClassic.AddressSpace(currentBank >> 5), at: 0x4000)
                operation.controller.sendSwitch(bank: GameboyClassic.AddressSpace(currentBank & 0x1F), at: 0x2000)
            }
            else {
                operation.controller.sendSwitch(bank: GameboyClassic.AddressSpace(currentBank), at: 0x2100)
                if currentBank >= 0x100 {
                    operation.controller.sendSwitch(bank: 1, at: 0x3000)
                }
            }
            
            let address = GameboyClassic.AddressSpace(currentBank > 1 ? 0x4000 : 0x0000)
            operation.controller.sendGo(to: GameboyClassic.AddressSpace(address))
            operation.controller.sendBeginReading()
            
            operation.readCondition.wait()
            operation.controller.sendHaltReading()
            let prefix = operation.bytesRead.suffix(from: operation.bytesRead.count - 0x4000).map { String($0, radix: 16, uppercase: true)}.joined(separator: " ")
            print(#function, operation.bytesRead, prefix.prefix(0x40))
        }
    }
    
    fileprivate static func advance(_ operation: ReadCartridgeOperation<GBxCartReaderController<GameboyClassic>>) {
    }
}

fileprivate enum GBxCartCommand<Platform: Gibby.Platform> {
    case  set(bank: Platform.AddressSpace)
    case bank(address: Platform.AddressSpace)
    case goto(address: Platform.AddressSpace)
    case halt
    case proceed
    case read
    
    private var encodedData: Data {
        var asciiCommand: UInt8 {
            switch self {
            case  .set:     return 0x42     // 'B'
            case .bank:     return 0x42     // 'B'
            case .goto:     return 0x41     // 'A'
            case .halt:     return 0x30     // '0'
            case .proceed:  return 0x31     // '1'
            case .read:
                switch Platform.self {
                case is GameboyClassic.Type:
                    return 0x52 // 'R'
                case is GameboyAdvance.Type:
                    return 0x72 // 'r'
                default:
                    fatalError("Unable to deduce command code for invalid platform.")
                }
            }
        }
        
        var stringFormat: String {
            switch self {
            case  .set:     return "%c%d"
            case .bank:     return "%c%x"
            case .goto:     return "%c%x"
            case .halt:     return "%c"
            case .proceed:  return "%c"
            case .read:     return "%c"
            }
        }

        switch self {
        case  .set(let bank):    print("bank (set):"); return String(format: stringFormat, asciiCommand, bank as! CVarArg).data(using: .ascii)!
        case .bank(let address): print("bank (addr):"); return String(format: stringFormat, asciiCommand, address as! CVarArg).data(using: .ascii)!
        case .goto(let address): print("goto: \(address)"); return String(format: stringFormat, asciiCommand, address as! CVarArg).data(using: .ascii)!
        case .halt:              print("halt:"); return String(format: stringFormat, asciiCommand as CVarArg).data(using: .ascii)!
        case .proceed:           return String(format: stringFormat, asciiCommand as CVarArg).data(using: .ascii)!
        case .read:              print("read:"); return String(format: stringFormat, asciiCommand as CVarArg).data(using: .ascii)!
        }
    }
    
    private func dataToSend() -> [Data] {
        switch self {
        case .halt:     return [encodedData]
        case .proceed:  return [encodedData]
        case .read:     return [encodedData]
        default:        return [encodedData, Data([0x0])]
        }
    }
    
    fileprivate static func send(to controller: GBxCartReaderController<Platform>, commands: GBxCartCommand<Platform>...) {
        commands
            .flatMap { $0.dataToSend() }
            .forEach {
                if !$0.starts(with: [0x31]) {
                    print($0.map { String($0, radix: 10, uppercase: true)}.joined(separator: " "))
                }
                controller.reader.send($0)
        }
    }
}
