import ORSSerial
import Gibby

final class GBxCartridgeControllerClassic<Cartridge: Gibby.Cartridge>: GBxCartridgeController<Cartridge> where Cartridge.Platform == GameboyClassic {
    fileprivate var dataToSend: Data? {
        didSet {
            if let data = dataToSend {
                if data != Data([0x31]) {
                    print(#function, #line, "Data: \(data.hexString())")
                }
                self.send(data)
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
            guard let header = self.header, header.isLogoValid else {
                print("WARNING: invalid header detected!")
                print(self.header!)
                operation.cancel()
                return
            }
        }
        
        let header: GameboyClassic.Cartridge.Header! = {
            if case let .read(_, context as OperationContext) = intent, context != .header {
                return self.header as? GameboyClassic.Cartridge.Header
            }
            else {
                return nil
            }
        }()
        
        //----------------------------------------------------------------------
        // READ
        //----------------------------------------------------------------------
        if case let .read(_, context as OperationContext) = intent {
            switch context {
            case .header:
                self.dataToSend = "A100\0".bytes()
                self.dataToSend = "R".bytes()
            case .cartridge:
                print(NSString(string: #file).lastPathComponent, #function, #line, "\n\(header!)")
                self.dataToSend = "A0\0".bytes()
                timeout(.veryLong)
                self.dataToSend = "R".bytes()
            case .saveFile:
                switch header.configuration {
                //--------------------------------------------------------------
                // MBC2 "fix"
                //--------------------------------------------------------------
                case .one, .two:
                    //----------------------------------------------------------
                    // START; STOP
                    //----------------------------------------------------------
                    self.dataToSend = "A0\0".bytes()
                    self.dataToSend = "R".bytes()
                    self.dataToSend = "0".bytes()
                default: (/* do nothing */)
                }
                
                //--------------------------------------------------------------
                // SET: the 'RAM' mode (MBC1-ONLY)
                //--------------------------------------------------------------
                if case .one = header.configuration {
                    self.switch(to: 1, at: 0x6000)
                }
                
                //--------------------------------------------------------------
                // TOGGLE
                //--------------------------------------------------------------
                self.toggle(ram: true)
                
                //--------------------------------------------------------------
                // BANK SWITCH
                //--------------------------------------------------------------
                self.switch(to: 0, at: 0x4000)
                
                //--------------------------------------------------------------
                // START
                //--------------------------------------------------------------
                self.dataToSend = "AA000\0".bytes()
                timeout(.veryLong)
                self.dataToSend = "R".bytes()
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
            let header: GameboyClassic.Cartridge.Header! = {
                if case let .read(_, context as OperationContext) = intent, context != .header {
                    return self.header as? GameboyClassic.Cartridge.Header
                }
                else {
                    return nil
                }
            }()
            let completedUnitCount = Int(progress.completedUnitCount)
            
            //------------------------------------------------------------------
            // OPERATION
            //------------------------------------------------------------------
            switch context {
            case .cartridge:
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
                    print("#\(bank), \(progress.fractionCompleted)%")

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
                if case let bank = completedUnitCount / header.ramBankSize, completedUnitCount % header.ramBankSize == 0 {
                    //----------------------------------------------------------
                    // DEBUG
                    //----------------------------------------------------------
                    print("#\(bank), \(progress.fractionCompleted)%")
                }
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
