import ORSSerial
import Gibby


/**
 An opaque `GBxSerialPortController` subclass, capable of performing
 platform-specific read routines.
 */
public class GBxCartridgeController<Cartridge: Gibby.Cartridge>: GBxSerialPortController, CartridgeController {
    /// DEBUG
    public var printStacktrace: Bool = false
    public var printProgress: Bool = false
}

final class GBxCartridgeControllerClassic: GBxCartridgeController<GameboyClassic.Cartridge> {
    private enum ReaderCommand: CustomDebugStringConvertible {
        case start
        case stop
        case `continue`
        case address(_ command: String, radix: Int, address: Int)
        case sleep(_ duration: UInt32)
        case write(bytes: Data)
        
        var debugDescription: String {
            var desc = ""
            switch self {
            case .start:
                desc += "START:\n"
            case .stop:
                desc += "STOP:\n"
            case .continue:
                desc += "CONT:\n"
            case .address(let command, let radix, let address):
                let addr = String(address, radix: radix, uppercase: true)
                desc += "ADDR: \(command);\(radix);\(addr)\n"
            case .sleep(let duration):
                desc += "SLP: \(duration)\n"
            case .write(bytes: let data):
                desc += "WRT: \(data.count)"
            }
            desc += data.hexString()
            return desc
        }
        
        private var data: Data {
            switch self {
            case .start:
                return "R".data(using: .ascii)!
            case .stop:
                return "0".data(using: .ascii)!
            case .continue:
                return "1".data(using: .ascii)!
            case .address(let command, let radix, let address):
                let addr = String(address, radix: radix, uppercase: true)
                return "\(command)\(addr)\0".data(using: .ascii)!
            case .write(bytes: let data):
                return "W".data(using: .ascii)! + data
            default:
                return Data()
            }
        }

        func send(to reader: ORSSerialPort) {
            guard case .sleep(let duration) = self else {
                reader.send(self.data)
                return
            }
            usleep(duration)
        }
    }

    /// The amount of microseconds between setting the bank address, and
    /// settings the bank number.
    ///
    /// - warning: Modifying or removing `timeout` will cause bank switching
    /// to fail! There is a tolerance of how low it can be set; for best
    /// results, stay between _150_ & _250_.
    private let timeout: UInt32 = 250
    //------------------------------------------------------------------

    /**
     */
    private func send(_ command: ReaderCommand...) {
        command.forEach {
            $0.send(to: self.reader)
        }
    }

    /**
     */
    @objc func readOperationWillBegin(_ operation: Operation) {
        guard let readOp = operation as? SerialPortOperation<GBxCartridgeController<Cartridge>> else {
            operation.cancel()
            return
        }
        
        if printStacktrace {
            print(#function, readOp.context)
        }
        
        switch readOp.context {
        case .header:
            //------------------------------------------------------------------
            // 1. set the start address to be read (stopping first; '\0')
            let address = Int(Cartridge.Platform.headerRange.lowerBound)
            self.send(.address("\0A", radix: 16, address: address))
            //------------------------------------------------------------------
        case .bank(let bank, let cartridge):
            //------------------------------------------------------------------
            // 1. stop sending
            // 2. switch the ROM bank
            // 3. set the start address to be read (stopping first; '\0')
            self.send(.stop)
            self.set(bank: bank, with: cartridge.header!)
            self.send(.address("\0A", radix: 16, address: bank > 1 ? 0x4000 : 0x0000))
            //------------------------------------------------------------------
        case .saveFile(let header, _):
            //--------------------------------------------------------------
            // MBC2 "fix"
            //--------------------------------------------------------------
            // MBC2 Fix (unknown why this fixes reading the ram, maybe has
            // to read ROM before RAM?). Read 64 bytes of ROM,
            // (really only 1 byte is required).
            //--------------------------------------------------------------
            // 1. set the start address to be read (stopping first; '\0')
            switch header.configuration {
            case .one, .two:
                self.send(.address("\0A", radix: 16, address: 0x0000), .start, .stop)
            default: (/* do nothing? */)
            }
            //--------------------------------------------------------------
            if case .one = header.configuration {
                // set the 'RAM' mode (MBC1-only)
                self.send(
                    .address("B", radix: 16, address: 0x6000)
                    , .sleep(timeout)
                    , .address("B", radix: 10, address: 1)
                )
            }
            //------------------------------------------------------------------
            // Initialize memory-bank controller
            self.send(
                .address("B", radix: 16, address: 0x0000)
                , .sleep(timeout)
                , .address("B", radix: 10, address: 0x0A)
            )
            //------------------------------------------------------------------
        case .sram(let bank, _):
            //------------------------------------------------------------------
            // 1. stop sending
            // 2. switch the RAM bank (then timeout)
            // 3. set the start address to be read (stopping first; '\0')
            self.send(.stop)
            self.send(
                .address("B", radix: 16, address: 0x4000)
                , .sleep(timeout)
                , .address("B", radix: 10, address: bank)
                , .address("\0A", radix: 16, address: 0xA000)
            )
            //------------------------------------------------------------------
        default: ()
        }
    }
    
    /**
     */
    @objc func readOperationDidBegin(_ operation: Operation) {
        guard let readOp = operation as? SerialPortOperation<GBxCartridgeController<Cartridge>> else {
            operation.cancel()
            return
        }

        if printStacktrace {
            print(#function, readOp.context)
        }
        
        switch readOp.context {
        case .header:
            self.send(.start)
        case .bank:
            self.send(.start)
        case .sram(let bank, let context):
            switch context {
            case .saveFile(_, .read):
                self.send(.start)
            case .saveFile(let header, .write(let data)):
                let startAddress = bank * header.ramBankSize
                let endAddress   = startAddress.advanced(by: 64)
                let dataToWrite  = data[startAddress..<endAddress]
                self.send(.write(bytes: dataToWrite))
            default: (/* no-op */)
            }
        default: ()
        }
    }

    /**
     */
    @objc func readOperation(_ operation: Operation, didUpdate progress: Progress) {
        guard let readOp = operation as? SerialPortOperation<GBxCartridgeController<Cartridge>> else {
            operation.cancel()
            return
        }
        
        let pageSize = 64

        switch readOp.context {
        case .cartridge:
            fallthrough
        case .saveFile:
            if printProgress {
                print(".", terminator: "")
            }
        case .sram(let bank, saveFile: let context):
            if (Int(progress.completedUnitCount) % pageSize) == 0 {
                switch context {
                case .saveFile(_, .read):
                    self.send(.continue)
                case .saveFile(let header, .write(let data)):
                    let startAddress = (bank * header.ramBankSize) + Int(progress.completedUnitCount)
                    let endAddress   = startAddress.advanced(by: pageSize)
                    let dataToWrite  = data[startAddress..<endAddress]
                    self.send(.write(bytes: dataToWrite))
                default: ()
                }
            }
        default:
            if (Int(progress.completedUnitCount) % pageSize) == 0 {
                self.send(.continue)
            }
        }
    }
    
    /**
     */
    @objc func readOperationDidComplete(_ operation: Operation) {
        self.reader.delegate = nil
        
        guard let readOp = operation as? SerialPortOperation<GBxCartridgeController<Cartridge>> else {
            operation.cancel()
            return
        }
        
        if printStacktrace {
            print(#function, readOp.context)
        }
        
        switch readOp.context {
        case .cartridge:
            self.close()
        case .saveFile:
            self.send(
                  .stop
                , .address("B", radix: 16, address: 0x0000)
                , .sleep(500) // ORLY?! Yes...this "very" high timeout fixed a
                              // _ton_ of 'readRAM' issues for specific carts.
                              // The pattern appears to be MBC5+RAM carts....?
                , .address("B", radix: 10, address: 0)
            )
            self.close()
        case .header:
            /// - warning: Another important 'pause'; don't delete.
            self.send(.stop, .sleep(75))
            self.close()
        default: ()
        }
    }

    private func set(bank: Int, with header: GameboyClassic.Cartridge.Header) {
        if case .one = header.configuration {
            self.send(
                .address("B", radix: 16, address: 0x6000)
                , .sleep(timeout)
                , .address("B", radix: 10, address: 0)
            )
            
            self.send(
                .address("B", radix: 16, address: 0x4000)
                , .sleep(timeout)
                , .address("B", radix: 10, address: bank >> 5)
            )
            
            self.send(
                .address("B", radix: 16, address: 0x2000)
                , .sleep(timeout)
                , .address("B", radix: 10, address: bank & 0x1F)
            )
        }
        else {
            self.send(
                .address("B", radix: 16, address: 0x2100)
                , .sleep(timeout)
                , .address("B", radix: 10, address: bank)
            )
            if bank >= 0x100 {
                self.send(
                    .address("B", radix: 16, address: 0x3000)
                    , .sleep(timeout)
                    , .address("B", radix: 10, address: 1)
                )
            }
        }
    }
}

final class GBxCartridgeControllerAdvance: GBxCartridgeController<GameboyAdvance.Cartridge> {
    /**
     */
    @objc func readOperationWillBegin(_ operation: Operation) {
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
    @objc func readOperationDidBegin(_ operation: Operation) {
        guard let _ = operation as? SerialPortOperation<GBxCartridgeController<Cartridge>> else {
            operation.cancel()
            return
        }
    }
    
    /**
     */
    @objc func readOperation(_ operation: Operation, didRead progress: Progress) {
        guard let _ = operation as? SerialPortOperation<GBxCartridgeController<Cartridge>> else {
            operation.cancel()
            return
        }
    }
    
    /**
     */
    @objc func readOperationDidComplete(_ operation: Operation) {
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
