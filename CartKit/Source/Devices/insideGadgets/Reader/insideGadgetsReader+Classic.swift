import Gibby

extension InsideGadgetsReader where Cartridge.Platform == GameboyClassic {
    public func header(result: @escaping (Result<Cartridge.Header, CartridgeReaderError<Cartridge>>) -> ()) {
        self.controller.add(BlockOperation {
            result(self.header(prepare: { $0.toggleRAM(on: false) }).mapError { .invalidHeader($0) })
        })
    }
    
    public func cartridge(progress callback: @escaping (Double) -> (), result: @escaping (Result<Cartridge, CartridgeReaderError<Cartridge>>) -> ()) {
        self.controller.add(BlockOperation {
            result(self.cartridge(callback))
        })
    }

    public func backup(progress callback: @escaping (Double) -> (), result: @escaping (Result<Data,Error>) ->()) {
        self.controller.add(BlockOperation{
            result(self.backup(callback))
        })
    }

    public func restore(data: Data, progress callback: @escaping (Double) -> (), result: @escaping (Result<(),Error>) -> ()) {
        self.controller.add(BlockOperation{
            result(self.restore(data: data, callback))
        })
    }
    
    public func delete(progress callback: @escaping (Double) -> (), result: @escaping (Result<(), Error>) -> ()) {
        self.controller.add(BlockOperation {
            result(self.delete(callback))
        })
    }
    
    private func cartridge(_ callback: @escaping (Double) -> ()) -> Result<Cartridge, CartridgeReaderError<Cartridge>> {
        precondition(!Thread.current.isMainThread)
        return Result {
            let header = try await { self.header(result: $0) }
            //------------------------------------------------------------------
            let progress = Progress(totalUnitCount: Int64(header.romSize))
            let observer = progress.observe(\.fractionCompleted, options: [.new]) { progress, change in
                DispatchQueue.main.sync {
                    callback(change.newValue ?? 0)
                }
            }
            defer { observer.invalidate() }
            //------------------------------------------------------------------
            var cartridgeData = Data()
            for bank in 0..<header.romBanks {
                progress.becomeCurrent(withPendingUnitCount: Int64(header.romBankSize))
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
                progress.resignCurrent()
            }
            return Cartridge(bytes: cartridgeData)
            }
            .mapError { .invalidCartridge($0) }
    }

    private func backup(_ callback: @escaping (Double) -> ()) -> Result<Data, Error> {
        precondition(!Thread.current.isMainThread)
        return Result {
            let header = try await { self.header(result: $0) }
            //------------------------------------------------------------------
            let progress = Progress(totalUnitCount: Int64(header.ramSize))
            let observer = progress.observe(\.fractionCompleted, options: [.new]) { progress, change in
                DispatchQueue.main.sync {
                    callback(change.newValue ?? 0)
                }
            }
            defer { observer.invalidate() }
            //------------------------------------------------------------------
            let ramBankSize = Int64(header.ramBankSize)
            var backupData = Data()
            for bank in 0..<header.ramBanks {
                progress.becomeCurrent(withPendingUnitCount: ramBankSize)
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
                progress.resignCurrent()
            }
            return backupData
        }
    }
    
    private func restore(data: Data, _ callback: @escaping (Double) -> ()) -> Result<(), Error> {
        precondition(!Thread.current.isMainThread)
        return Result {
            let header = try await { self.header(result: $0) }
            //------------------------------------------------------------------
            let progress = Progress(totalUnitCount: Int64(header.ramSize))
            let observer = progress.observe(\.fractionCompleted, options: [.new]) { progress, change in
                DispatchQueue.main.sync {
                    callback(change.newValue ?? 0)
                }
            }
            defer { observer.invalidate() }
            //------------------------------------------------------------------
            for bank in 0..<header.ramBanks {
                let startIndex = bank * header.ramBankSize
                let endIndex   = startIndex.advanced(by: header.ramBankSize)
                //--------------------------------------------------------------
                let slice  = data[startIndex..<endIndex]
                let ramBankSize = Int64(slice.count)
                //--------------------------------------------------------------
                progress.becomeCurrent(withPendingUnitCount: ramBankSize)
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
                progress.resignCurrent()
            }
        }
    }
    
    private func delete(_ callback: @escaping (Double) -> ()) -> Result<(), Error> {
        precondition(!Thread.current.isMainThread)
        return self
            .header(prepare: { $0.toggleRAM(on: false) })
            .mapError { $0 }
            .map { Data(count: $0.ramSize) }
            .flatMap { self.restore(data: $0, callback) }
    }
}

