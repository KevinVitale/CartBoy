import ORSSerial
import Gibby

/**
 A controller which manages the serial port interations as it relates to Gameboy
 readers and writesr.
 
 - note: `Cartridge` headers are required for all operations.
 - note: ROM files are _"read"_ & _"written"_, or _"erased"_ (the latter two, if they are a `FlashCart`).
 - note: Save files are _"backed-up"_, _"restored"_, or _"deleted"_, if the `Cartridge` has **SRAM** support.
 */
public protocol CartridgeController {
    /// The associated platform that the adopter relates to.
    associatedtype Cartridge: Gibby.Cartridge

    func header(result: @escaping ((Cartridge.Header?) -> ()))
    func read(header: Cartridge.Header?, result: @escaping ((Cartridge?) -> ()))
    func backup(header: Cartridge.Header?, result: @escaping (Data?, Cartridge.Header) -> ())
    func restore(from backup: Data, header: Cartridge.Header?, result: @escaping (Bool) -> ())
    func delete(header: Cartridge.Header?, result: @escaping (Bool) -> ())
}

public protocol FlashCartridgeController {
    associatedtype Cartridge: Gibby.Cartridge
}

enum CartridgeControllerContext<Cartridge: Gibby.Cartridge> {
    case header
    case cartridge(Cartridge.Header)
    case saveFile(Cartridge.Header)
    case boardInfo
}

extension SerialPacketOperationDelegate where Self: SerialPortController, Self: CartridgeController {
    typealias Context = CartridgeControllerContext<Cartridge>
    
    fileprivate func read(_ context: Context, result: @escaping ((Data?) -> ())) {
        switch context {
        case .header:
            let headerSize = Cartridge.Platform.headerRange.count
            let intent = SerialPacketOperation<Self, Context>.Intent.read(count: headerSize, context: context)
            SerialPacketOperation(delegate: self, intent: intent, result: result).start()
        case .cartridge(let header):
            guard header.isLogoValid, header.romSize > 0 else {
                result(nil)
                return
            }
            let intent = SerialPacketOperation<Self, Context>.Intent.read(count: header.romSize, context: context)
            SerialPacketOperation(delegate: self, intent: intent, result: result).start()
        case .saveFile(let header):
            guard header.isLogoValid, header.ramSize > 0 else {
                result(nil)
                return
            }
            let intent = SerialPacketOperation<Self, Context>.Intent.read(count: header.ramSize, context: context)
            SerialPacketOperation(delegate: self, intent: intent, result: result).start()
        default:
            result(nil)
            return
        }
    }
    
    fileprivate func write(_ context: Context, data: Data, result: @escaping ((Data?) -> ())) {
        switch context {
        case .header:
            return result(nil)
        case .cartridge:
            let intent = SerialPacketOperation<Self, Context>.Intent.write(data: data, context: context)
            SerialPacketOperation(delegate: self, intent: intent, result: result).start()
        case .saveFile:
            let intent = SerialPacketOperation<Self, Context>.Intent.write(data: data, context: context)
            SerialPacketOperation(delegate: self, intent: intent, result: result).start()
        default:
            result(nil)
            return
        }
    }
}

extension SerialPortController where Self: CartridgeController {
    public func header(result: @escaping ((Cartridge.Header?) -> ())) {
        self.read(.header) {
            guard let data = $0 else {
                result(nil)
                return
            }
            let header = Cartridge.Header(bytes: data)
            guard header.isLogoValid else {
                result(nil)
                return
            }
            result(header)
        }
    }
    
    public func read(header: Cartridge.Header? = nil, result: @escaping ((Cartridge?) -> ())) {
        guard let header = header else {
            self.header {
                self.read(header: $0, result: result)
            }
            return
        }
        self.read(.cartridge(header)) {
            guard let data = $0 else {
                result(nil)
                return
            }
            result(.init(bytes: data))
        }
    }
    
    public func backup(header: Cartridge.Header? = nil, result: @escaping (Data?, Cartridge.Header) -> ()) {
        guard let header = header else {
            self.header {
                self.backup(header: $0, result: result)
            }
            return
        }
        self.read(.saveFile(header)) {
            guard let data = $0 else {
                result(nil, header)
                return
            }
            result(data, header)
        }
    }
    
    public func restore(from backup: Data, header: Cartridge.Header? = nil, result: @escaping (Bool) -> ()) {
        guard let header = header else {
            self.header {
                self.restore(from: backup, header: $0, result: result)
            }
            return
        }
        guard header.ramSize == backup.count else {
            result(false)
            return
        }
        self.write(.saveFile(header), data: backup) {
            guard let _ = $0 else {
                result(false)
                return
            }
            result(true)
        }
    }
    
    public func delete(header: Cartridge.Header? = nil, result: @escaping (Bool) -> ()) {
        guard let header = header else {
            self.header {
                self.delete(header: $0, result: result)
            }
            return
        }
        self.restore(from: Data(count: header.ramSize), header: header, result: result)
    }
}
