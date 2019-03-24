import ORSSerial
import Gibby

final class GBxCartridgeControllerClassic<Cartridge: Gibby.Cartridge>: GBxCartridgeController<Cartridge> where Cartridge.Platform == GameboyClassic {
    @objc override func packetOperation(_ operation: Operation, didBeginWith intent: Any?) {
        super.packetOperation(operation, didBeginWith: intent)
        //----------------------------------------------------------------------
        // BREAK LOOPS
        //----------------------------------------------------------------------
        self.send("0\0".bytes(), timeout: 250)
        self.switch(to: 0x00, at: 0x0000)

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
                guard header.configuration.hardware.contains(.ram) else {
                    operation.cancel()
                    return
                }
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
                self.switch(to: 0x0A, at: 0x0000)

                //--------------------------------------------------------------
                // BANK SWITCH
                //--------------------------------------------------------------
                self.switch(to: 0x0, at: 0x4000)
                
                //--------------------------------------------------------------
                // START
                //--------------------------------------------------------------
                self.send("AA000\0".bytes())
                self.send("R".bytes())
            case .whileOpened: return
            default:
                operation.cancel()
                return
            }
        }
        //----------------------------------------------------------------------
        // WRITE
        //----------------------------------------------------------------------
        else if case .write(let data, _, let context)? = intent as? Intent {
            switch context {
            case .saveFile(let header as GameboyClassic.Cartridge.Header):
                guard header.configuration.hardware.contains(.ram) else {
                    operation.cancel()
                    return
                }
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
                self.switch(to: 0x0A, at: 0x0000)
                
                //--------------------------------------------------------------
                // BANK SWITCH
                //--------------------------------------------------------------
                self.switch(to: 0x0, at: 0x4000)
                
                //--------------------------------------------------------------
                // START
                //--------------------------------------------------------------
                self.send("AA000\0".bytes())
                self.send("W".data(using: .ascii)! + data[..<64])
            default:
                print(data)
            }
        }
    }
    
    @objc func packetOperation(_ operation: Operation, didUpdate progress: Progress, with intent: Any?) {
        guard let intent = intent as? Intent else {
            operation.cancel()
            return
        }
        
        let completedUnitCount = Int(progress.completedUnitCount)
        
        //----------------------------------------------------------------------
        // READ
        //----------------------------------------------------------------------
        if case let .read(_, context) = intent {
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
                    
                    self.send("0\0".bytes())
                    self.switch(to: bank, at: 0x4000)
                    self.send("AA000\0".bytes())
                    self.send("R".bytes())
                }
                else {
                    self.send("1".bytes(), timeout: 250)
                }
            case .header:
                self.send("1".bytes(), timeout: 250)
            case .whileOpened: return
            default:
                operation.cancel()
                return
            }
        }
        //----------------------------------------------------------------------
        // WRITE
        //----------------------------------------------------------------------
        else if case .write(let data, let count, let context) = intent {
            switch context {
            case .saveFile(let header as GameboyClassic.Cartridge.Header):
                let startAddress = completedUnitCount * count
                let range = startAddress..<startAddress + count
                if case let bank = startAddress / header.ramBankSize, startAddress % header.ramBankSize == 0 {
                    //----------------------------------------------------------
                    // DEBUG
                    //----------------------------------------------------------
                    print("#\(bank), \(progress.fractionCompleted)%")
                    
                    self.send("0\0".bytes())
                    self.switch(to: bank, at: 0x4000)
                    self.send("AA000\0".bytes())
                    self.send("W".data(using: .ascii)! + data[range])
                }
                else {
                    self.send("W".data(using: .ascii)! + data[range])
                }
            default:
                print(data)
            }
        }
    }
}

extension GBxCartridgeControllerClassic {
    fileprivate func `switch`(to bank: Int, at address: Int) {
        self.send("B", number: address)
        self.send("B", number: bank, radix: 10)
    }
}
