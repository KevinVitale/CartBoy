import Gibby

extension InsideGadgetsReader where Cartridge.Platform == GameboyClassic, Cartridge.Header.Index == Cartridge.Platform.AddressSpace {
    public func header(result: @escaping (Result<Cartridge.Header,CartridgeReaderError<Cartridge>>) -> ()) {
        self.controller.add(BlockOperation {
            result(self.header(prepare: { $0.toggleRAM(on: false) }))
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
        return self
            .header(prepare: { $0.toggleRAM(on: false) })
            .map { header -> Cartridge.Header in
                defer {
                    self.progress = .init(totalUnitCount: Int64(header.romSize))
                    DispatchQueue.main.sync { progress(self.progress) }
                }
                return header
            }
            .map { header in (0..<header.romBanks).map { bank in (bank, header) } }
            .map { $0.map { bank, header -> Result<Data, Error> in
                defer { self.progress.resignCurrent() }
                //--------------------------------------------------------------
                self.progress.becomeCurrent(withPendingUnitCount: Int64(header.romBankSize))
                //--------------------------------------------------------------
                return self.read(totalBytes: header.romBankSize
                    , startingAt: bank > 0 ? 0x4000 : 0x0000
                    , prepare: {
                        $0.mbc2(fix: header)
                        //------------------------------------------------------
                        guard bank > 0 else {
                            return
                        }
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
                })
                }
            }
            .flatMap { romBankResults -> Result<[Data], CartridgeReaderError<Cartridge>> in
                Result {
                    try romBankResults.map { try $0.get() }
                }
                .mapError { .invalidCartridge($0) }
            }
            .map { $0.flatMap { $0 }}
            .map { Cartridge(bytes: Data($0))}
    }

    public func backup(_ progress: @escaping (Progress) -> ()) -> Result<Data, Error> {
        precondition(!Thread.current.isMainThread)
        return self
            .header(prepare: { $0.toggleRAM(on: false) })
            .map { header -> Cartridge.Header in
                defer {
                    self.progress = .init(totalUnitCount: Int64(header.ramSize))
                    DispatchQueue.main.sync { progress(self.progress) }
                }
                return header
            }
            .map { header in (0..<header.ramBanks).map { bank in (bank, header) } }
            .map { $0.map { bank, header -> Result<Data, Error> in
                let totalBytes = Int64(header.ramBankSize)
                //--------------------------------------------------------------
                defer { self.progress.resignCurrent() }
                //--------------------------------------------------------------
                self.progress.becomeCurrent(withPendingUnitCount: totalBytes)
                //--------------------------------------------------------------
                return self.read(totalBytes: totalBytes
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
                })
                }
            }
            .flatMap { ramBankResults in
                Result {
                    try ramBankResults.map { try $0.get() }
                }
                .mapError { .invalidCartridge($0) }
            }
            .map { dataArray -> [UInt8] in dataArray.flatMap { $0 } }
            .map { Data($0) }
            .mapError { $0 }
    }
    
    public func restore(data: Data, _ progress: @escaping (Progress) -> ()) -> Result<(), Error> {
        precondition(!Thread.current.isMainThread)
        return self
            .header(prepare: { $0.toggleRAM(on: false) })
            .map { header -> Cartridge.Header in
                defer {
                    self.progress = .init(totalUnitCount: Int64(header.ramSize))
                    DispatchQueue.main.sync { progress(self.progress) }
                }
                return header
            }
            .map { header in (0..<header.ramBanks).map { ($0, header) } }
            .map { $0.map { bank, header -> (Int, Data, Cartridge.Header) in
                let startIndex = bank * header.ramBankSize
                let endIndex   = startIndex.advanced(by: header.ramBankSize)
                return (bank, data[startIndex..<endIndex], header) }
            }
            .map { $0.map { element -> Result<Data, Error> in
                let (bank, slice, header) = element
                let totalBytes = Int64(slice.count)
                //--------------------------------------------------------------
                defer { self.progress.resignCurrent() }
                //--------------------------------------------------------------
                self.progress.becomeCurrent(withPendingUnitCount: totalBytes)
                //--------------------------------------------------------------
                return self.request(totalBytes: totalBytes / 64
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
                })
                }
            }
            .flatMap { ramBankResults in
                Result {
                    try ramBankResults.map { try $0.get() }
                    }
                    .mapError { .invalidCartridge($0) }
            }
            .map { dataArray in dataArray.flatMap { $0 } }
            .map { _ in }
            .mapError { $0 }
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

