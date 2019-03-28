import Gibby

extension InsideGadgetsReader where Cartridge.Platform == GameboyClassic {
    public func readHeader(result: @escaping (Cartridge.Header?) -> ()) -> Operation {
        let timeout: UInt32 = 250
        return SerialPortOperation(controller: self.controller, progress: Progress(totalUnitCount: Int64(Cartridge.Platform.headerRange.count)), perform: { progress in
            guard progress.completedUnitCount > 0 else {
                self.controller.send("0".bytes(),  timeout: timeout)
                self.controller.send("B", number: 0x0000, radix: 16, terminate: true, timeout: timeout)
                self.controller.send("B", number: 000000, radix: 10, terminate: true, timeout: timeout)
                self.controller.send("A100\0".bytes(), timeout: timeout)
                self.controller.send("R".bytes(), timeout: timeout)
                return
            }
            guard progress.completedUnitCount % 64 == 0 else {
                return
            }
            self.controller.send("1".bytes(), timeout: timeout)
        }) { data in
            self.controller.send("0\0".bytes(), timeout: timeout)
            guard let data = data else {
                result(nil)
                return
            }
            
            result(.init(bytes: data))
        }
    }
    
    public func readCartridge(with header: Cartridge.Header? = nil, result: @escaping (Cartridge?) -> ()) -> Operation {
        guard let header = header as? GameboyClassic.Cartridge.Header else {
            return self.readHeader {
                return self.readCartridge(with: $0, result: result).start()
            }
        }
        print(header)
        return SerialPortOperation(controller: controller, progress: Progress(totalUnitCount: Int64(header.romSize)), perform: { progress in
            guard progress.completedUnitCount > 0 else {
                self.controller.send("0".bytes(),  timeout: 0)
                self.controller.send("B", number: 0x0000, radix: 16, terminate: true, timeout: 0)
                self.controller.send("B", number: 000000, radix: 10, terminate: true, timeout: 0)
                self.controller.send("A0\0".bytes(), timeout: 250)
                self.controller.send("R".bytes(), timeout: 0)
                return
            }
            guard progress.completedUnitCount % 64 == 0 else {
                return
            }
            if case let bank = progress.completedUnitCount / Int64(header.romBankSize), bank >= 1, progress.completedUnitCount % Int64(header.romBankSize) == 0 {
                self.controller.send("0\0".bytes(), timeout: 0)
                switch header.configuration {
                case .one:
                    self.controller.send("B", number: 0x6000, radix: 16, terminate: true, timeout: 0)
                    self.controller.send("B", number: bank, radix: 10, terminate: true, timeout: 0)
                    
                    self.controller.send("B", number: 0x4000, radix: 16, terminate: true, timeout: 0)
                    self.controller.send("B", number: bank >> 5, radix: 10, terminate: true, timeout: 0)
                    
                    self.controller.send("B", number: 0x2000, radix: 16, terminate: true, timeout: 0)
                    self.controller.send("B", number: (bank & 0x1F), radix: 10, terminate: true, timeout: 0)
                default:
                    self.controller.send("B", number: 0x2100, radix: 16, terminate: true, timeout: 0)
                    self.controller.send("B", number: bank, radix: 10, terminate: true, timeout: 0)
                    if bank >= 0x100 {
                        self.controller.send("B", number: 0x3000, radix: 16, terminate: true, timeout: 0)
                        self.controller.send("B", number: 1, radix: 10, terminate: true, timeout: 0)
                    }
                }
                print(".", separator: "", terminator: "")
                self.controller.send("A4000\0".bytes(), timeout: 0)
                self.controller.send("R".bytes(),    timeout: 0)
            }
            else {
                self.controller.send("1".bytes(), timeout: 0)
            }
        }) { data in
            self.controller.send("0\0".bytes(), timeout: 0)
            guard let data = data else {
                result(nil)
                return
            }
            
            result(.init(bytes: data))
        }
    }
    
    public func backupSave(with header: Cartridge.Header? = nil, result: @escaping (Data?) -> ()) -> Operation {
        guard let header = header as? GameboyClassic.Cartridge.Header else {
            return self.readHeader {
                return self.backupSave(with: $0, result: result).start()
            }
        }
        print(header)
        return SerialPortOperation(controller: self.controller, progress: Progress(totalUnitCount: Int64(header.ramSize)), perform: { progress in
            guard progress.completedUnitCount > 0 else {
                self.controller.send("0\0".bytes(),  timeout: 0)
                
                switch header.configuration {
                    //--------------------------------------------------------------
                    // MBC2 "fix"
                //--------------------------------------------------------------
                case .one, .two:
                    //----------------------------------------------------------
                    // START; STOP
                    //----------------------------------------------------------
                    self.controller.send("0".bytes(), timeout: 0)
                    self.controller.send("A0\0".bytes(), timeout: 0)
                    self.controller.send("R".bytes(), timeout: 0)
                    self.controller.send("0\0".bytes(), timeout: 0)
                default: (/* do nothing */)
                }
                //--------------------------------------------------------------
                // SET: the 'RAM' mode (MBC1-ONLY)
                //--------------------------------------------------------------
                if case .one = header.configuration {
                    self.controller.send("B", number: 0x6000, radix: 16, terminate: true, timeout: 0)
                    self.controller.send("B", number: 1, radix: 10, terminate: true, timeout: 0)
                }
                
                //--------------------------------------------------------------
                // TOGGLE
                //--------------------------------------------------------------
                self.controller.send("B", number: 0x0000, radix: 16, terminate: true, timeout: 0)
                self.controller.send("B", number: 0x0A, radix: 10, terminate: true, timeout: 0)
                
                //--------------------------------------------------------------
                // BANK SWITCH
                //--------------------------------------------------------------
                self.controller.send("B", number: 0x4000, radix: 16, terminate: true, timeout: 0)
                self.controller.send("B", number: 0x0, radix: 10, terminate: true, timeout: 0)
                
                //--------------------------------------------------------------
                // START
                //--------------------------------------------------------------
                self.controller.send("AA000\0".bytes(), timeout: 0)
                self.controller.send("R".bytes(), timeout: 0)
                return
            }
            guard progress.completedUnitCount % 64 == 0 else {
                return
            }
            if case let bank = progress.completedUnitCount / Int64(header.ramBankSize), progress.completedUnitCount % Int64(header.ramBankSize) == 0 {
                print("#\(bank), \(progress.fractionCompleted)%")
                
                self.controller.send("0".bytes(), timeout: 0)
                self.controller.send("B", number: 0x4000, radix: 16, terminate: true, timeout: 0)
                self.controller.send("B", number: bank, radix: 10, terminate: true, timeout: 0)
                self.controller.send("AA000\0".bytes(), timeout: 250)
                self.controller.send("R".bytes(), timeout: 0)
            }
            else {
                self.controller.send("1".bytes(), timeout: 0)
            }
        }) { data in
            self.controller.send("0\0".bytes(), timeout: 0)
            result(data)
        }
    }
    
    public func restoreSave(data: Data, with header: Cartridge.Header? = nil, result: @escaping (Bool) -> ()) -> Operation {
        guard let header = header as? GameboyClassic.Cartridge.Header else {
            return self.readHeader {
                return self.restoreSave(data: data, with: $0, result: result).start()
            }
        }
        print(header)
        guard header.isLogoValid, header.ramBankSize != 0 else {
            return BlockOperation {
                result(false)
            }
        }
        return SerialPortOperation(controller: self.controller, progress: Progress(totalUnitCount: Int64(data.count / 64)), perform: { progress in
            guard progress.completedUnitCount > 0 else {
                self.controller.send("0\0".bytes(),  timeout: 0)
                
                switch header.configuration {
                    //--------------------------------------------------------------
                    // MBC2 "fix"
                //--------------------------------------------------------------
                case .one, .two:
                    //----------------------------------------------------------
                    // START; STOP
                    //----------------------------------------------------------
                    self.controller.send("0".bytes(), timeout: 0)
                    self.controller.send("A0\0".bytes(), timeout: 0)
                    self.controller.send("R".bytes(), timeout: 0)
                    self.controller.send("0\0".bytes(), timeout: 0)
                default: (/* do nothing */)
                }
                //--------------------------------------------------------------
                // SET: the 'RAM' mode (MBC1-ONLY)
                //--------------------------------------------------------------
                if case .one = header.configuration {
                    self.controller.send("B", number: 0x6000, radix: 16, terminate: true, timeout: 0)
                    self.controller.send("B", number: 1, radix: 10, terminate: true, timeout: 0)
                }
                
                //--------------------------------------------------------------
                // TOGGLE
                //--------------------------------------------------------------
                self.controller.send("B", number: 0x0000, radix: 16, terminate: true, timeout: 0)
                self.controller.send("B", number: 0x0A, radix: 10, terminate: true, timeout: 0)
                
                //--------------------------------------------------------------
                // BANK SWITCH
                //--------------------------------------------------------------
                self.controller.send("B", number: 0x4000, radix: 16, terminate: true, timeout: 0)
                self.controller.send("B", number: 0x0, radix: 10, terminate: true, timeout: 0)
                
                //--------------------------------------------------------------
                // START
                //--------------------------------------------------------------
                self.controller.send("AA000\0".bytes(), timeout: 0)
                self.controller.send("W".data(using: .ascii)! + data[..<64], timeout: 0)
                return
            }
            let startAddress = Int(progress.completedUnitCount * 64)
            let range = startAddress..<Int(startAddress + 64)
            if case let bank = startAddress / header.ramBankSize, startAddress % header.ramBankSize == 0 {
                print("#\(bank), \(progress.fractionCompleted)%")
                
                self.controller.send("0".bytes(), timeout: 0)
                self.controller.send("B", number: 0x4000, radix: 16, terminate: true, timeout: 0)
                self.controller.send("B", number: bank, radix: 10, terminate: true, timeout: 0)
                self.controller.send("AA000\0".bytes(), timeout: 250)
                self.controller.send("W".data(using: .ascii)! + data[range], timeout: 0)
            }
            else {
                self.controller.send("W".data(using: .ascii)! + data[range], timeout: 0)
            }
        }) { _ in
            self.controller.send("0\0".bytes(), timeout: 0)
            result(true)
        }
    }
    
    public func deleteSave(with header: Cartridge.Header? = nil, result: @escaping (Bool) -> ()) -> Operation {
        guard let header = header else {
            return self.readHeader {
                return self.deleteSave(with: $0, result: result).start()
            }
        }
        return self.restoreSave(data: Data(count: header.ramSize), with: header, result: result)
    }
}

