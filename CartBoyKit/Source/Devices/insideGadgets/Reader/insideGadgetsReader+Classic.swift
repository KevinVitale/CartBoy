import Gibby

extension InsideGadgetsReader where Cartridge.Platform == GameboyClassic, Cartridge.Header.Index == Cartridge.Platform.AddressSpace {
    public func readHeader(result: @escaping (Cartridge.Header?) -> ()) {
        let range = Cartridge.Platform.headerRange
        let count = Int64(range.count)
        self.resetProgress(to: Int64(count))
        self.read(count, at: range.lowerBound, prepare: {
            $0.toggleRAM(on: false)
        }) { data in
            defer { self.resetProgress(to: 0) }
            result(.init(bytes: data ?? Data(count: Int(count))))
        }
    }
    
    public func readCartridge(with header: Cartridge.Header? = nil, result: @escaping (Cartridge?) -> ()) {
        guard let header = header else {
            self.readHeader { [weak self] in
                return self?.readCartridge(with: $0, result: result)
            }
            return
        }
        
        self.controller.add(BlockOperation { [weak self] in
            let group = DispatchGroup()
            group.enter()
            //------------------------------------------------------------------
            let romBankCount = header.romBanks
            //------------------------------------------------------------------
            var romBanks = [Int:Data]() {
                didSet {
                    if romBanks.count == romBankCount {
                        group.leave()
                    }
                }
            }
            //------------------------------------------------------------------
            self?.resetProgress(to: Int64(header.romSize))
            //------------------------------------------------------------------
            for bank in 0..<romBankCount {
                //--------------------------------------------------------------
                let address = UInt16(bank > 0 ? 0x4000 : 0x0000)
                //--------------------------------------------------------------
                self?.read(header.romBankSize, at: address, prepare: {
                    $0.mbc2(fix: header)
                    //----------------------------------------------------------
                    $0.toggleRAM(on: false)
                    //----------------------------------------------------------
                    guard bank > 0 else {
                        return
                    }
                    if case .one = header.configuration {
                        $0.set(bank:           0, at: 0x6000)
                        $0.set(bank:   bank >> 5, at: 0x4000)
                        $0.set(bank: bank & 0x1F, at: 0x2000)
                    }
                    else {
                        $0.set(bank: bank, at: 0x2100)
                    }
                }) { data in
                    if let data = data {
                        romBanks[bank] = data
                    }
                }
            }
            //------------------------------------------------------------------
            group.wait()
            defer { self?.resetProgress(to: 0) }
            //------------------------------------------------------------------
            // Order the map from 'lowest' to 'highest' bank number; flatten.
            let cartridgeData = romBanks
                .sorted(by: { $0.key < $1.key })
                .reduce(into: Data()) { $0.append($1.value) }
            //------------------------------------------------------------------
            result(.init(bytes: cartridgeData))
        })
    }
    
    public func backupSave(with header: Cartridge.Header? = nil, result: @escaping (Data?) -> ()) {
        guard let header = header as? GameboyClassic.Cartridge.Header else {
            self.readHeader {
                self.backupSave(with: $0, result: result)
            }
            return
        }
        
        self.controller.add(BlockOperation { [weak self] in
            let group = DispatchGroup()
            group.enter()
            var ramBanks = [Int:Data]() {
                didSet {
                    if ramBanks.count == header.ramBanks {
                        group.leave()
                    }
                }
            }
            
            self?.resetProgress(to: Int64(header.ramSize))
            for bank in 0..<header.ramBanks {
                self?.read(header.ramBankSize, at: 0xA000, prepare: {
                    $0.mbc2(fix: header)
                    //----------------------------------------------------------
                    // SET: the 'RAM' mode (MBC1-ONLY)
                    //----------------------------------------------------------
                    if case .one = header.configuration {
                        $0.set(bank: 1, at: 0x6000)
                    }
                    //----------------------------------------------------------
                    $0.toggleRAM(on: true)
                    $0.set(bank: bank, at: 0x4000)
                }) { data in
                    self?.controller.toggleRAM(on: false)
                    if let data = data {
                        ramBanks[bank] = data
                    }
                }
            }
            
            group.wait()
            defer { self?.resetProgress(to: Int64(0)) }

            let saveData = ramBanks
                .sorted(by: { $0.key < $1.key })
                .reduce(into: Data()) { $0.append($1.value) }
            
            result(saveData)
        })
    }
    
    public func restoreSave(data: Data, with header: Cartridge.Header? = nil, result: @escaping (Bool) -> ()) {
        guard let header = header as? GameboyClassic.Cartridge.Header else {
            self.readHeader {
                self.restoreSave(data: data, with: $0, result: result)
            }
            return
        }
        guard header.isLogoValid, header.ramBankSize > 0 else {
            result(false)
            return
        }
        let operation = SerialPortOperation(controller: self.controller, unitCount: Int64(data.count / 64), packetLength: 1, perform: { progress in
            let startAddress = Int(progress.completedUnitCount * 64)
            let range = startAddress..<Int(startAddress + 64)
            if case let bank = startAddress / header.ramBankSize, startAddress % header.ramBankSize == 0 {
                if bank == 0 {
                    self.controller.toggleRAM(on: true)
                }
                //--------------------------------------------------------------
                self.controller.stop()
                self.controller.mbc2(fix: header)
                //--------------------------------------------------------------
                // SET: the 'RAM' mode (MBC1-ONLY)
                //--------------------------------------------------------------
                if case .one = header.configuration {
                    self.controller.set(bank: 1, at: 0x6000)
                }
                //--------------------------------------------------------------
                self.controller.set(bank: bank, at: 0x4000)
                self.controller.go(to: 0xA000)
                self.controller.restore(data[range])
            }
            else {
                self.controller.restore(data[range])
            }
        }) { _ in
            defer { self.progress.totalUnitCount = 0 }
            self.controller.stop()
            self.controller.toggleRAM(on: false)
            result(true)
            return
        }
        self.controller.add(operation)
    }
    
    public func deleteSave(with header: Cartridge.Header? = nil, result: @escaping (Bool) -> ()) {
        guard let header = header else {
            return self.readHeader {
                return self.deleteSave(with: $0, result: result)
            }
        }
        return self.restoreSave(data: Data(count: header.ramSize), with: header, result: result)
    }
}

