import ORSSerial
import Gibby


/**
 An opaque `GBxSerialPortController` subclass, capable of performing
 platform-specific serial port operations.
 */
public class GBxCartridgeController<Cartridge: Gibby.Cartridge>: GBxSerialPortController, CartridgeController {
}

extension GBxCartridgeController {
    public func header(result: @escaping ((Cartridge.Header?) -> ())) {
        self.addOperation(SerialPacketOperation(controller: self, delegate: self, intent: .read(count: Cartridge.Platform.headerRange.count, context: OperationContext.header)) {
            guard let data = $0 else {
                result(nil)
                return
            }
            result(.init(bytes: data))
        })
    }
}
