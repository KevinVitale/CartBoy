import ORSSerial
import Gibby


/**
 An opaque `GBxSerialPortController` subclass, capable of performing
 platform-specific serial port operations.
 */
public class GBxCartridgeController<Cartridge: Gibby.Cartridge>: GBxSerialPortController, CartridgeController {
    private(set) var header: Cartridge.Header? = nil
    
    public func header(result: @escaping ((Cartridge.Header?) -> ())) {
        self.addOperation(SerialPacketOperation(controller: self, delegate: self, intent: .read(count: Cartridge.Platform.headerRange.count, context: OperationContext.header)) { [weak self] in
            guard let data = $0 else {
                result(nil)
                return
            }
            self?.header = .init(bytes: data)
            result(self?.header)
        })
    }
}

extension GBxCartridgeController where Cartridge: FlashCart {
    func write(to flashCart: Cartridge, result: @escaping (Bool) ->()) {
        
    }
    
    func erase(flashCart: Cartridge, result: @escaping (Bool) ->()) {
        
    }
}
