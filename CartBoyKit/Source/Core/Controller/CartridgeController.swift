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

    /**
     */
    func header(result: @escaping ((Self.Cartridge.Header?) -> ()))
    
    /**
     */
    func read(header: Self.Cartridge.Header?, result: @escaping ((Self.Cartridge?) -> ()))
    
    /**
     */
    func backup(header: Self.Cartridge.Header?, result: @escaping (Data?, Self.Cartridge.Header) -> ())
    
    /**
     */
    func restore(from backup: Data, header: Self.Cartridge.Header?, result: @escaping (Bool) -> ())
    
    /**
     */
    func delete(header: Self.Cartridge.Header?, result: @escaping (Bool) -> ())
}

extension CartridgeController where Self: SerialPacketOperationDelegate {
    public func read(header: Cartridge.Header? = nil, result: @escaping ((Cartridge?) -> ())) {
        guard let header = header else {
            self.header {
                self.read(header: $0, result: result)
            }
            return
        }
        self.addOperation(SerialPacketOperation(controller: self, delegate: self, intent: .read(count: header.romSize, context: OperationContext.cartridge)) {
            guard let data = $0 else {
                result(nil)
                return
            }
            result(.init(bytes: data))
        })
    }
    
    public func backup(header: Cartridge.Header? = nil, result: @escaping (Data?, Cartridge.Header) -> ()) {
        if let header = header {
            guard header.ramSize > 0 else {
                result(nil, header)
                return
            }
            self.addOperation(SerialPacketOperation(controller: self, delegate: self, intent: .read(count: header.ramSize, context: OperationContext.saveFile)) {
                guard let data = $0 else {
                    result(nil, header)
                    return
                }
                result(data, header)
            })
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
            self.addOperation(SerialPacketOperation(controller: self, delegate: self, intent: .write(data: backup)) { _ in
                result(true)
            })
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
