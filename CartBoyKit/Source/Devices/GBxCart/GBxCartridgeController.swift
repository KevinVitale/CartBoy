import ORSSerial
import Gibby


/**
 An opaque `GBxSerialPortController` subclass, capable of performing
 platform-specific serial port operations.
 */
public class GBxCartridgeController<Cartridge: Gibby.Cartridge>: GBxSerialPortController, CartridgeController {
    @objc public func packetOperation(_ operation: Operation, didBeginWith intent: Any?) {
        guard let intent = intent as? Intent<GBxCartridgeController<Cartridge>> else {
            operation.cancel()
            return
        }
        
        if case .read(_, let context) = intent {
            switch context {
            case .cartridge(let header) where !header.isLogoValid: fallthrough
            case  .saveFile(let header) where !header.isLogoValid:
                operation.cancel()
                return
            default: (/* do nothing */)
            }
        }
    }

    @objc public func packetLength(for intent: Any?) -> UInt {
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
