import Gibby

extension InsideGadgetsReader where Cartridge.Platform == GameboyClassic {
    public func readHeader<Controller>(using controller: Controller, result: @escaping (Cartridge.Header?) -> ()) -> Operation where Controller: SerialPortController {
        let timeout: UInt32 = 250
        return SerialPortOperation(controller: controller, progress: Progress(totalUnitCount: Int64(Cartridge.Platform.headerRange.count)), perform: { progress in
            guard progress.completedUnitCount > 0 else {
                controller.send("0".bytes(),  timeout: timeout)
                controller.send("B", number: 0x0000, radix: 16, terminate: true, timeout: timeout)
                controller.send("B", number: 000000, radix: 10, terminate: true, timeout: timeout)
                controller.send("A100\0".bytes(), timeout: timeout)
                controller.send("R".bytes(), timeout: timeout)
                return
            }
            guard progress.completedUnitCount % 64 == 0 else {
                return
            }
            controller.send("1".bytes(), timeout: timeout)
        }) { data in
            controller.send("0\0".bytes(), timeout: timeout)
            guard let data = data else {
                result(nil)
                return
            }
            
            result(.init(bytes: data))
        }
    }
    
    public func readCartridge<Controller>(using controller: Controller, with header: Cartridge.Header? = nil, result: @escaping (Cartridge?) -> ()) -> Operation where Controller : SerialPortController {
        guard let header = header as? GameboyClassic.Cartridge.Header else {
            return self.readHeader(using: controller) {
                return self.readCartridge(using: controller, with: $0, result: result).start()
            }
        }
        print(header)
        return SerialPortOperation(controller: controller, progress: Progress(totalUnitCount: Int64(header.romSize)), perform: { progress in
            guard progress.completedUnitCount > 0 else {
                controller.send("0".bytes(),  timeout: 0)
                controller.send("B", number: 0x0000, radix: 16, terminate: true, timeout: 0)
                controller.send("B", number: 000000, radix: 10, terminate: true, timeout: 0)
                controller.send("A0\0".bytes(), timeout: 250)
                controller.send("R".bytes(), timeout: 0)
                return
            }
            guard progress.completedUnitCount % 64 == 0 else {
                return
            }
            if case let bank = progress.completedUnitCount / Int64(header.romBankSize), bank >= 1, progress.completedUnitCount % Int64(header.romBankSize) == 0 {
                controller.send("0\0".bytes(), timeout: 0)
                switch header.configuration {
                case .one:
                    controller.send("B", number: 0x6000, radix: 16, terminate: true, timeout: 0)
                    controller.send("B", number: bank, radix: 10, terminate: true, timeout: 0)
                    
                    controller.send("B", number: 0x4000, radix: 16, terminate: true, timeout: 0)
                    controller.send("B", number: bank >> 5, radix: 10, terminate: true, timeout: 0)
                    
                    controller.send("B", number: 0x2000, radix: 16, terminate: true, timeout: 0)
                    controller.send("B", number: (bank & 0x1F), radix: 10, terminate: true, timeout: 0)
                default:
                    controller.send("B", number: 0x2100, radix: 16, terminate: true, timeout: 0)
                    controller.send("B", number: bank, radix: 10, terminate: true, timeout: 0)
                    if bank >= 0x100 {
                        controller.send("B", number: 0x3000, radix: 16, terminate: true, timeout: 0)
                        controller.send("B", number: 1, radix: 10, terminate: true, timeout: 0)
                    }
                }
                print(".", separator: "", terminator: "")
                controller.send("A4000\0".bytes(), timeout: 0)
                controller.send("R".bytes(),    timeout: 0)
            }
            else {
                controller.send("1".bytes(), timeout: 0)
            }
        }) { data in
            controller.send("0\0".bytes(), timeout: 0)
            guard let data = data else {
                result(nil)
                return
            }
            
            result(.init(bytes: data))
        }
    }
    
    public func backupSave<Controller>(using controller: Controller, with header: Cartridge.Header? = nil, result: @escaping (Data?) -> ()) -> Operation where Controller : SerialPortController {
        guard let header = header as? GameboyClassic.Cartridge.Header else {
            return self.readHeader(using: controller) {
                return self.backupSave(using: controller, with: $0, result: result).start()
            }
        }
        print(header)
        return SerialPortOperation(controller: controller, progress: Progress(totalUnitCount: Int64(header.ramSize)), perform: { progress in
            guard progress.completedUnitCount > 0 else {
                controller.send("0\0".bytes(),  timeout: 0)
                
                switch header.configuration {
                    //--------------------------------------------------------------
                    // MBC2 "fix"
                //--------------------------------------------------------------
                case .one, .two:
                    //----------------------------------------------------------
                    // START; STOP
                    //----------------------------------------------------------
                    controller.send("0".bytes(), timeout: 0)
                    controller.send("A0\0".bytes(), timeout: 0)
                    controller.send("R".bytes(), timeout: 0)
                    controller.send("0\0".bytes(), timeout: 0)
                default: (/* do nothing */)
                }
                //--------------------------------------------------------------
                // SET: the 'RAM' mode (MBC1-ONLY)
                //--------------------------------------------------------------
                if case .one = header.configuration {
                    controller.send("B", number: 0x6000, radix: 16, terminate: true, timeout: 0)
                    controller.send("B", number: 1, radix: 10, terminate: true, timeout: 0)
                }
                
                //--------------------------------------------------------------
                // TOGGLE
                //--------------------------------------------------------------
                controller.send("B", number: 0x0000, radix: 16, terminate: true, timeout: 0)
                controller.send("B", number: 0x0A, radix: 10, terminate: true, timeout: 0)
                
                //--------------------------------------------------------------
                // BANK SWITCH
                //--------------------------------------------------------------
                controller.send("B", number: 0x4000, radix: 16, terminate: true, timeout: 0)
                controller.send("B", number: 0x0, radix: 10, terminate: true, timeout: 0)
                
                //--------------------------------------------------------------
                // START
                //--------------------------------------------------------------
                controller.send("AA000\0".bytes(), timeout: 0)
                controller.send("R".bytes(), timeout: 0)
                return
            }
            guard progress.completedUnitCount % 64 == 0 else {
                return
            }
            if case let bank = progress.completedUnitCount / Int64(header.ramBankSize), progress.completedUnitCount % Int64(header.ramBankSize) == 0 {
                print("#\(bank), \(progress.fractionCompleted)%")
                
                controller.send("0".bytes(), timeout: 0)
                controller.send("B", number: 0x4000, radix: 16, terminate: true, timeout: 0)
                controller.send("B", number: bank, radix: 10, terminate: true, timeout: 0)
                controller.send("AA000\0".bytes(), timeout: 250)
                controller.send("R".bytes(), timeout: 0)
            }
            else {
                controller.send("1".bytes(), timeout: 0)
            }
        }) { data in
            controller.send("0\0".bytes(), timeout: 0)
            result(data)
        }
    }
    
    public func restoreSave<Controller>(data: Data, using controller: Controller, with header: Cartridge.Header? = nil, result: @escaping (Bool) -> ()) -> Operation where Controller : SerialPortController {
        guard let header = header as? GameboyClassic.Cartridge.Header else {
            return self.readHeader(using: controller) {
                return self.restoreSave(data: data, using: controller, with: $0, result: result).start()
            }
        }
        print(header)
        return SerialPortOperation(controller: controller, progress: Progress(totalUnitCount: Int64(header.ramSize)), perform: { progress in
            guard progress.completedUnitCount > 0 else {
                controller.send("0\0".bytes(),  timeout: 0)
                
                switch header.configuration {
                    //--------------------------------------------------------------
                    // MBC2 "fix"
                //--------------------------------------------------------------
                case .one, .two:
                    //----------------------------------------------------------
                    // START; STOP
                    //----------------------------------------------------------
                    controller.send("0".bytes(), timeout: 0)
                    controller.send("A0\0".bytes(), timeout: 0)
                    controller.send("R".bytes(), timeout: 0)
                    controller.send("0\0".bytes(), timeout: 0)
                default: (/* do nothing */)
                }
                //--------------------------------------------------------------
                // SET: the 'RAM' mode (MBC1-ONLY)
                //--------------------------------------------------------------
                if case .one = header.configuration {
                    controller.send("B", number: 0x6000, radix: 16, terminate: true, timeout: 0)
                    controller.send("B", number: 1, radix: 10, terminate: true, timeout: 0)
                }
                
                //--------------------------------------------------------------
                // TOGGLE
                //--------------------------------------------------------------
                controller.send("B", number: 0x0000, radix: 16, terminate: true, timeout: 0)
                controller.send("B", number: 0x0A, radix: 10, terminate: true, timeout: 0)
                
                //--------------------------------------------------------------
                // BANK SWITCH
                //--------------------------------------------------------------
                controller.send("B", number: 0x4000, radix: 16, terminate: true, timeout: 0)
                controller.send("B", number: 0x0, radix: 10, terminate: true, timeout: 0)
                
                //--------------------------------------------------------------
                // START
                //--------------------------------------------------------------
                controller.send("AA000\0".bytes(), timeout: 0)
                controller.send("W".data(using: .ascii)! + data[..<64], timeout: 0)
                return
            }
            guard progress.completedUnitCount % 64 == 0 else {
                return
            }
            let startAddress = Int(progress.completedUnitCount * 64)
            let range = startAddress..<Int(startAddress + 64)
            if case let bank = startAddress / header.ramBankSize, startAddress % header.ramBankSize == 0 {
                print("#\(bank), \(progress.fractionCompleted)%")
                
                controller.send("0".bytes(), timeout: 0)
                controller.send("B", number: 0x4000, radix: 16, terminate: true, timeout: 0)
                controller.send("B", number: bank, radix: 10, terminate: true, timeout: 0)
                controller.send("AA000\0".bytes(), timeout: 250)
                controller.send("W".data(using: .ascii)! + data[range], timeout: 0)
            }
            else {
                controller.send("1".bytes(), timeout: 0)
            }
        }) { _ in
            controller.send("0\0".bytes(), timeout: 0)
            result(true)
        }
    }
    
    public func deleteSave<Controller: SerialPortController>(using controller: Controller, with header: Cartridge.Header? = nil, result: @escaping (Bool) -> ()) -> Operation {
        guard let header = header else {
            return self.readHeader(using: controller) {
                return self.deleteSave(using: controller, with: $0, result: result).start()
            }
        }
        return self.restoreSave(data: Data(count: header.ramSize), using: controller, with: header, result: result)
    }
}

