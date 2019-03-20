import ORSSerial
import Gibby


/**
 An opaque `GBxSerialPortController` subclass, capable of performing
 platform-specific serial port operations.
 */
public class GBxCartridgeController<Cartridge: Gibby.Cartridge>: GBxSerialPortController, CartridgeController {
    public func packetOperation(_ operation: Operation, didComplete buffer: Data, with intent: Any?) {
        guard let _ = intent as? Intent<GBxCartridgeController<Cartridge>> else {
            operation.cancel()
            return
        }
        
        self.isOpenCondition.whileLocked {
            self.delegate = nil
            self.isOpenCondition.signal()
        }
    }
    
    public func packetLength(for intent: Any?) -> UInt {
        guard let intent = intent as? Intent<GBxCartridgeController<Cartridge>> else {
            fatalError()
        }
        
        switch intent {
        case .read:
            return 64
        case .write:
            return 1
        }
    }
}
