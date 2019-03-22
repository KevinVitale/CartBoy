import ORSSerial
import Gibby

final class GBxCartridgeControllerClassic<Cartridge: Gibby.Cartridge>: GBxCartridgeController<Cartridge> where Cartridge.Platform == GameboyClassic {
    @discardableResult
    override func send(_ data: Data?, timeout: UInt32? = nil) -> Bool {
        defer { usleep(250) }
        return super.send(data, timeout: timeout)
    }
    
    @objc override func packetOperation(_ operation: Operation, didBeginWith intent: Any?) {
        super.packetOperation(operation, didBeginWith: intent)
        //----------------------------------------------------------------------
        // BREAK LOOPS
        //----------------------------------------------------------------------
        self.send("0\0".bytes(), timeout: 250)

        //----------------------------------------------------------------------
        // READ
        //----------------------------------------------------------------------
        if case let .read(_, context)? = intent as? Intent {
            switch context {
            case .header:
                self.send("A100\0".bytes())
                self.send("R".bytes())
            case .cartridge:
                self.send("A0\0".bytes())
                self.send("R".bytes())
            case .saveFile(let header as GameboyClassic.Cartridge.Header):
                switch header.configuration {
                //--------------------------------------------------------------
                // MBC2 "fix"
                //--------------------------------------------------------------
                case .one, .two:
                    //----------------------------------------------------------
                    // START; STOP
                    //----------------------------------------------------------
                    self.send("A0\0".bytes())
                    self.send("R".bytes())
                    self.send("0\0".bytes())
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
                self.send("AA000\0".bytes())
                self.send("R".bytes())
            default:
                operation.cancel()
                return
            }
        }
        //----------------------------------------------------------------------
        // WRITE
        //----------------------------------------------------------------------
        else if case .write(let data, _)? = intent as? Intent {
            print(data)
        }
    }
    
    @objc func packetOperation(_ operation: Operation, didUpdate progress: Progress, with intent: Any?) {
        guard let intent = intent as? Intent else {
            operation.cancel()
            return
        }
        
        //----------------------------------------------------------------------
        // READ
        //----------------------------------------------------------------------
        if case let .read(_, context) = intent {
            let completedUnitCount = Int(progress.completedUnitCount)
            
            //------------------------------------------------------------------
            // OPERATION
            //------------------------------------------------------------------
            switch context {
            case .cartridge(let header as GameboyClassic.Cartridge.Header):
                if case let bank = completedUnitCount / header.romBankSize, bank >= 1, completedUnitCount % header.romBankSize == 0 {
                    //----------------------------------------------------------
                    // STOP
                    //----------------------------------------------------------
                    self.send("0\0".bytes())
                    
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
                    // print("#\(bank), \(progress.fractionCompleted)%")
                    print(".", separator: "", terminator: "")

                    //----------------------------------------------------------
                    // START
                    //----------------------------------------------------------
                    self.send("A4000\0".bytes())
                    self.send("R".bytes())
                }
                else {
                    //----------------------------------------------------------
                    // CONTINUE
                    //----------------------------------------------------------
                    self.send("1".bytes())
                }
            case .saveFile(let header):
                if case let bank = completedUnitCount / header.ramBankSize, completedUnitCount % header.ramBankSize == 0 {
                    //----------------------------------------------------------
                    // DEBUG
                    //----------------------------------------------------------
                    print("#\(bank), \(progress.fractionCompleted)%")
                }
                fallthrough
            case .header:
                self.send("1".bytes(), timeout: 250)
            default:
                operation.cancel()
                return
            }
        }
        //----------------------------------------------------------------------
        // WRITE
        //----------------------------------------------------------------------
        else if case .write(let data, _) = intent {
            
            print(data)
        }
    }
    
    @objc override func packetOperation(_ operation: Operation, didComplete intent: Any?) {
        defer {
            super.packetOperation(operation, didComplete: intent)
        }
        
        guard let intent = intent as? Intent else {
            return
        }
        
        if case let .read(_, context) = intent {
            switch context {
            case .saveFile(_):
                self.toggle(ram: false)
            default: (/* do nothing */)
            }
        }
    }
}

extension GBxCartridgeControllerClassic {
    private func bank(_ command: String = "B", address: Int, radix: Int = 16) {
        self.send("\(command)\(String(address, radix: radix, uppercase: true))\0".bytes())
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
