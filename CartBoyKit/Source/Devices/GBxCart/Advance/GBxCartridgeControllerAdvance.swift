import ORSSerial
import Gibby

final class GBxCartridgeControllerAdvance<Cartridge: Gibby.Cartridge>: GBxCartridgeController<Cartridge> where Cartridge.Platform == GameboyAdvance {
    /**
     */
    @objc func portOperationWillBegin(_ operation: Operation) {
        guard let readOp = operation as? SerialPortOperation<GBxCartridgeController<Cartridge>> else {
            operation.cancel()
            return
        }
        
        if printStacktrace {
            print(#function, readOp.context)
        }
    }
    
    /**
     */
    @objc func portOperationDidBegin(_ operation: Operation) {
        guard let _ = operation as? SerialPortOperation<GBxCartridgeController<Cartridge>> else {
            operation.cancel()
            return
        }
    }
    
    /**
     */
    @objc func portOperation(_ operation: Operation, didRead progress: Progress) {
        guard let _ = operation as? SerialPortOperation<GBxCartridgeController<Cartridge>> else {
            operation.cancel()
            return
        }
    }
    
    /**
     */
    @objc func portOperationDidComplete(_ operation: Operation) {
        self.reader.delegate = nil
        
        guard let readOp = operation as? SerialPortOperation<GBxCartridgeController<Cartridge>> else {
            operation.cancel()
            return
        }
        
        if printStacktrace {
            print(#function, readOp.context)
        }
    }
    
}
