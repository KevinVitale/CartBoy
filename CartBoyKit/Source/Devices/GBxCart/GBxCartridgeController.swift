import ORSSerial
import Gibby


/**
 An opaque `GBxSerialPortController` subclass, capable of performing
 platform-specific serial port operations.
 */
public class GBxCartridgeController<Cartridge: Gibby.Cartridge>: GBxSerialPortController, CartridgeController {
    public func header(result: @escaping ((Cartridge.Header?) -> ())) {
        self.addOperation(SerialPacketOperation(controller: self, delegate: self, intent: .read(count: Cartridge.Platform.headerRange.count, context: OperationContext.header)) {
            guard let data = $0 else {
                result(nil)
                return
            }
            result(.init(bytes: data))
        })
    }

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
    }
    
    public func restore(from backup: Data, header: Cartridge.Header? = nil, result: @escaping (Bool) -> ()) {
    }
    
    public func delete(header: Cartridge.Header? = nil, result: @escaping (Bool) -> ()) {
    }
}

extension GBxCartridgeController where Cartridge: FlashCart {
    func write(to flashCart: Cartridge, result: @escaping (Bool) ->()) {
        
    }
    
    func erase(flashCart: Cartridge, result: @escaping (Bool) ->()) {
        
    }
}
