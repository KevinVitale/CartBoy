import ORSSerial
import Gibby

final class GBxCartridgeControllerClassic<Cartridge: Gibby.Cartridge>: GBxCartridgeController<Cartridge> where Cartridge.Platform == GameboyClassic {
    public override func packetOperation(_ operation: Operation, didBeginWith intent: Any?) {
        guard let intent = intent as? PacketIntent, case .read(_, let context?) = intent, context is OperationContext else {
            operation.cancel()
            return
        }
        
        switch context as! OperationContext {
        case .header:
            self.reader.send("\0A100\0".data(using: .ascii)!)
            self.reader.send("R".data(using: .ascii)!)
        case .cartridge:
            self.reader.send("\0A0\0".data(using: .ascii)!)
            self.reader.send("R".data(using: .ascii)!)
        default:
            fatalError()
        }
    }
    
    public override func packetOperation(_ operation: Operation, didUpdate progress: Progress, with intent: Any?) {
        guard let intent = intent as? PacketIntent, case .read(_, let context?) = intent, context is OperationContext else {
            operation.cancel()
            return
        }
        
        self.reader.send("1".data(using: .ascii)!)
    }
}
