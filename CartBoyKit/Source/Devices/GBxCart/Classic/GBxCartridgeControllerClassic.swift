import ORSSerial
import Gibby

final class GBxCartridgeControllerClassic<Cartridge: Gibby.Cartridge>: GBxCartridgeController<Cartridge> where Cartridge.Platform == GameboyClassic {
    private enum Timeout: UInt32 {
        case short    = 250
        case medium   = 1000
        case long     = 5000
        case veryLong = 10000
    }
    
    private func timeout(_ timeout: Timeout = .short) {
        usleep(timeout.rawValue)
    }
    
    fileprivate var dataToSend: Data? {
        didSet {
            if let data = dataToSend {
                if data != Data([0x31]), printStacktrace {
                    print(#function, #line, "Data: \(data.hexString())")
                }
                self.reader.send(data)
                timeout()
            }
        }
    }
    
    public override func packetOperation(_ operation: Operation, didBeginWith intent: Any?) {
        guard let intent = intent as? PacketIntent, case .read(_, let context?) = intent, context is OperationContext else {
            operation.cancel()
            return
        }
        
        self.dataToSend = "0".bytes()
        timeout(.veryLong)
        
        //----------------------------------------------------------------------
        // HEADER CHECK
        //----------------------------------------------------------------------
        if case let .read(_, context as OperationContext) = intent, context != .header {
            guard let header = header, header.isLogoValid else {
                print("WARNING: invalid header detected!")
                print(self.header!)
                operation.cancel()
                return
            }
        }
        
        //----------------------------------------------------------------------
        // READ
        //----------------------------------------------------------------------
        if case let .read(_, context as OperationContext) = intent {
            switch context {
            case .header:
                self.dataToSend = "A100\0".bytes()
                self.dataToSend = "R".bytes()
            case .cartridge:
                print(header!)
                self.dataToSend = "A0\0".bytes()
                timeout(.veryLong)
                self.dataToSend = "R".bytes()
            case .saveFile:
                print(header!)
            }
        }
        //----------------------------------------------------------------------
        // WRITE
        //----------------------------------------------------------------------
        else if case .write(let data) = intent {
            print(data)
        }
    }
    
    public override func packetOperation(_ operation: Operation, didUpdate progress: Progress, with intent: Any?) {
        guard let intent = intent as? PacketIntent else {
            operation.cancel()
            return
        }
        
        //----------------------------------------------------------------------
        // READ
        //----------------------------------------------------------------------
        if case let .read(_, context as OperationContext) = intent {
            switch context {
            case .cartridge:
                let header = self.header as! GameboyClassic.Cartridge.Header
                let completedUnitCount = Int(progress.completedUnitCount)
                if case let bank = completedUnitCount / header.romBankSize, bank >= 1, completedUnitCount % header.romBankSize == 0 {
                    //----------------------------------------------------------
                    // STOP
                    //----------------------------------------------------------
                    self.dataToSend = "0".bytes()
                    
                    //----------------------------------------------------------
                    // BANK SWITCH
                    //----------------------------------------------------------
                    switch header.configuration {
                    case .one:
                        self.switch(to: 0, at: 0x6000)
                        self.switch(to: bank >> 5, at: 0x4000)
                        self.switch(to: (bank & 0x1F), at: 0x2000)
                    default:
                        self.switch(to: bank, at: 0x2100)
                        if bank >= 0x100 {
                            self.switch(to: 1, at: 0x3000)
                        }
                    }
                    
                    //----------------------------------------------------------
                    // DEBUG
                    //----------------------------------------------------------
                    if printProgress {
                        print("#\(bank), \(progress.fractionCompleted)%")
                    }
                    
                    //----------------------------------------------------------
                    // START
                    //----------------------------------------------------------
                    self.dataToSend = "A4000\0".bytes()
                    timeout(.short)
                    self.dataToSend = "R".bytes()
                }
                else {
                    //----------------------------------------------------------
                    // CONTINUE
                    //----------------------------------------------------------
                    self.dataToSend = "1".bytes()
                }
            case .saveFile:
                self.toggle(ram: true)
                fallthrough
            default:
                self.dataToSend = "1".bytes()
            }
        }
        //----------------------------------------------------------------------
        // WRITE
        //----------------------------------------------------------------------
        else if case .write(let data) = intent {
            print(data)
        }
    }
    
    override func packetOperation(_ operation: Operation, didComplete buffer: Data, with intent: Any?) {
        guard let intent = intent as? PacketIntent else {
            operation.cancel()
            return
        }
        
        if case let .read(_, context as OperationContext) = intent, context == .saveFile {
            self.toggle(ram: false)
        }
        
        super.packetOperation(operation, didComplete: buffer, with: intent)
    }
}

extension GBxCartridgeControllerClassic {
    private func bank(_ command: String = "B", address: Int, radix: Int = 16) {
        self.dataToSend = "\(command)\(String(address, radix: radix, uppercase: true))\0".bytes()
    }
    
    fileprivate func `switch`(to bank: Int, at address: Int) {
        self.bank(address: address)
        self.bank(address: bank, radix: 10)
    }
    
    fileprivate func toggle(ram mode: Bool) {
        self.bank(address: 0x0000)
        self.bank(address: mode ? 0x0A : 0x00, radix: 10)
    }
}

fileprivate extension BinaryInteger {
    func bytes(radix: Int = 16, uppercase: Bool = true, using encoding: String.Encoding = .ascii) -> Data? {
        guard let data = String(self, radix: radix, uppercase: uppercase).data(using: encoding) else {
            return nil
        }
        if radix == 10 {
            print(">>> \(data.hexString(radix: radix))")
        }
        return data
    }
}

fileprivate extension String {
    func bytes(using encoding: String.Encoding = .ascii) -> Data? {
        guard let data = self.data(using: encoding) else {
            return nil
        }
        return data
    }
}
