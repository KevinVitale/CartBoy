import Gibby

extension InsideGadgetsReader where Cartridge.Platform == GameboyClassic, Cartridge.Header.Index == Cartridge.Platform.AddressSpace {
    public func header(result: @escaping (Result<Cartridge.Header, CartridgeReaderError<Cartridge>>) -> ()) {
        self.controller.add(BlockOperation {
            result(self.header(prepare: { $0.toggleRAM(on: false) }).mapError { .invalidHeader($0) })
        })
    }
    
    public func cartridge(progress callback: @escaping (Progress) -> (), result: @escaping (Result<Cartridge, CartridgeReaderError<Cartridge>>) -> ()) {
        self.controller.add(BlockOperation {
            result(self.cartridge(callback))
        })
    }

    public func backup(progress callback: @escaping (Progress) -> (), result: @escaping (Result<Data,Error>) ->()) {
        self.controller.add(BlockOperation{
            result(self.backup(callback))
        })
    }

    public func restore(data: Data, progress callback: @escaping (Progress) -> (), result: @escaping (Result<(),Error>) -> ()) {
        self.controller.add(BlockOperation{
            result(self.restore(data: data, callback))
        })
    }
    
    public func delete(progress callback: @escaping (Progress) -> (), result: @escaping (Result<(), Error>) -> ()) {
        self.controller.add(BlockOperation {
            result(self.delete(callback))
        })
    }
    
    public func cartridge(_ progress: @escaping (Progress) -> ()) -> Result<Cartridge, CartridgeReaderError<Cartridge>> {
        precondition(!Thread.current.isMainThread)
        return Result {
            let header = try await { self.header(result: $0) }
            //------------------------------------------------------------------
            self.progress = .init(totalUnitCount: Int64(header.romSize))
            DispatchQueue.main.sync { progress(self.progress) }
            //------------------------------------------------------------------
            var cartridgeData = Data()
            for bank in 0..<header.romBanks {
                self.progress.becomeCurrent(withPendingUnitCount: Int64(header.romBankSize))
                //--------------------------------------------------------------
                let bankData = try self.read(totalBytes: header.romBankSize
                    , startingAt: bank > 0 ? 0x4000 : 0x0000
                    , prepare: {
                        $0.mbc2(fix: header)
                        //------------------------------------------------------
                        guard bank > 0 else { return }
                        //------------------------------------------------------
                        if case .one = header.configuration {
                            $0.set(bank:           0, at: 0x6000)
                            $0.set(bank:   bank >> 5, at: 0x4000)
                            $0.set(bank: bank & 0x1F, at: 0x2000)
                        }
                        else {
                            $0.set(bank: bank, at: 0x2100)
                            if bank > 0x100 {
                                $0.set(bank: 1, at: 0x3000)
                            }
                        }
                }).get()
                //--------------------------------------------------------------
                cartridgeData.append(bankData)
                //--------------------------------------------------------------
                self.progress.resignCurrent()
            }
            return Cartridge(bytes: cartridgeData)
            }
            .mapError { .invalidCartridge($0) }
    }

    public func backup(_ progress: @escaping (Progress) -> ()) -> Result<Data, Error> {
        precondition(!Thread.current.isMainThread)
        return Result {
            let header = try await { self.header(result: $0) }
            //------------------------------------------------------------------
            self.progress = .init(totalUnitCount: Int64(header.ramSize))
            DispatchQueue.main.sync { progress(self.progress) }
            //------------------------------------------------------------------
            let ramBankSize = Int64(header.ramBankSize)
            var backupData = Data()
            for bank in 0..<header.ramBanks {
                self.progress.becomeCurrent(withPendingUnitCount: ramBankSize)
                //--------------------------------------------------------------
                let bankData = try self.read(totalBytes: ramBankSize
                    , startingAt: 0xA000
                    , prepare: {
                        $0.mbc2(fix: header)
                        //--------------------------------------------------
                        // SET: the 'RAM' mode (MBC1-ONLY)
                        //--------------------------------------------------
                        if case .one = header.configuration {
                            $0.set(bank: 1, at: 0x6000)
                        }
                        //--------------------------------------------------
                        $0.toggleRAM(on: true)
                        $0.set(bank: bank, at: 0x4000)
                }).get()
                //--------------------------------------------------------------
                backupData.append(bankData)
                //--------------------------------------------------------------
                self.progress.resignCurrent()
            }
            return backupData
        }
    }
    
    public func restore(data: Data, _ progress: @escaping (Progress) -> ()) -> Result<(), Error> {
        precondition(!Thread.current.isMainThread)
        return Result {
            let header = try await { self.header(result: $0) }
            //------------------------------------------------------------------
            self.progress = .init(totalUnitCount: Int64(header.ramSize))
            DispatchQueue.main.sync { progress(self.progress) }
            //------------------------------------------------------------------
            for bank in 0..<header.ramBanks {
                let startIndex = bank * header.ramBankSize
                let endIndex   = startIndex.advanced(by: header.ramBankSize)
                //--------------------------------------------------------------
                let slice  = data[startIndex..<endIndex]
                let ramBankSize = Int64(slice.count)
                //--------------------------------------------------------------
                self.progress.becomeCurrent(withPendingUnitCount: ramBankSize)
                //--------------------------------------------------------------
                _ = try self.request(totalBytes: ramBankSize / 64
                    , packetSize: 1
                    , prepare: {
                        if bank == 0 { $0.toggleRAM(on: true) }
                        //--------------------------------------------------
                        $0.stop()
                        $0.mbc2(fix: header)
                        //--------------------------------------------------
                        // SET: the 'RAM' mode (MBC1-ONLY)
                        //--------------------------------------------------
                        if case .one = header.configuration {
                            $0.set(bank: 1, at: 0x6000)
                        }
                        //--------------------------------------------------
                        $0.set(bank: bank, at: 0x4000)
                        $0.go(to: 0xA000)
                        $0.restore(slice[slice.startIndex..<slice.startIndex.advanced(by: 64)])
                }, progress: { (controller, progress) in
                    let startAddress = Int(progress.completedUnitCount * 64).advanced(by: slice.startIndex)
                    let rangeOfBytes = startAddress..<Int(startAddress + 64)
                    controller.restore(slice[rangeOfBytes])
                }).get()
                //--------------------------------------------------------------
                self.progress.resignCurrent()
            }
        }
    }
    
    public func delete(_ progress: @escaping (Progress) -> ()) -> Result<(), Error> {
        precondition(!Thread.current.isMainThread)
        return self
            .header(prepare: { $0.toggleRAM(on: false) })
            .mapError { $0 }
            .map { Data(count: $0.ramSize) }
            .flatMap { self.restore(data: $0, progress) }
    }
}

