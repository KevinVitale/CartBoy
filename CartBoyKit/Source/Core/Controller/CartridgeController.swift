import ORSSerial
import Gibby

/**
 A controller which manages the serial port interations as it relates to Gameboy
 readers and writesr.
 
 - note: `Cartridge` headers are required for all operations.
 - note: ROM files are _"read"_ & _"written"_, or _"erased"_ (the latter two, if they are a `FlashCart`).
 - note: Save files are _"backed-up"_, _"restored"_, or _"deleted"_, if the `Cartridge` has **SRAM** support.
 */
public protocol CartridgeController: SerialPortController {
    /// The associated platform that the adopter relates to.
    associatedtype Cartridge: Gibby.Cartridge
}

extension CartridgeController {
    typealias Intent<Controller: CartridgeController> = SerialPacketOperation<Controller>.Intent
    typealias Context<Controller: CartridgeController> = SerialPacketOperation<Controller>.Context
    
    fileprivate func perform(_ intent: Intent<Self>, result: @escaping ((Data?) -> ())) {
        SerialPacketOperation(delegate: self, intent: intent, result: result).start()
    }
}

extension CartridgeController {
    public func header(result: @escaping ((Cartridge.Header?) -> ())) {
        let headerSize = Cartridge.Platform.headerRange.count
        self.perform(.read(count: headerSize, context: .header)) {
            guard let data = $0 else {
                result(nil)
                return
            }
            result(.init(bytes: data))
        }
    }
    
    public func read(header: Cartridge.Header? = nil, result: @escaping ((Cartridge?) -> ())) {
        guard let header = header else {
            self.header {
                self.read(header: $0, result: result)
            }
            return
        }

        self.perform(.read(count: header.romSize, context: .cartridge(header))) {
            guard let data = $0 else {
                result(nil)
                return
            }
            result(.init(bytes: data))
        }
    }
    
    public func backup(header: Cartridge.Header? = nil, result: @escaping (Data?, Cartridge.Header) -> ()) {
        if let header = header {
            guard header.ramSize > 0 else {
                result(nil, header)
                return
            }
            self.perform(.read(count: header.ramSize, context: .saveFile(header))) {
                guard let data = $0 else {
                    result(nil, header)
                    return
                }
                result(data, header)
            }
        }
        else {
            self.header {
                self.backup(header: $0, result: result)
            }
        }
    }
    
    public func restore(from backup: Data, header: Cartridge.Header? = nil, result: @escaping (Bool) -> ()) {
        if let header = header {
            guard header.ramSize == backup.count else {
                result(false)
                return
            }
            self.perform(.write(data: backup, context: .saveFile(header))) { _ in
                result(true)
            }
        }
        else {
            self.header {
                self.restore(from: backup, header: $0, result: result)
            }
        }
    }
    
    public func delete(header: Cartridge.Header? = nil, result: @escaping (Bool) -> ()) {
        if let header = header {
            self.restore(from: Data(count: header.ramSize), header: header, result: result)
        }
        else {
            self.header {
                guard let header = $0 else {
                    result(false)
                    return
                }
                self.delete(header: header, result: result)
            }
        }
    }
}
