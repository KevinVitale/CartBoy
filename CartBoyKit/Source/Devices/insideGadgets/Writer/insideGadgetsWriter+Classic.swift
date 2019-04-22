import Gibby
import ORSSerial

extension InsideGadgetsWriter where FlashCartridge == AM29F016B {
    public func erase(progress callback: @escaping (Progress) -> (), result: @escaping (Result<(), Error>) -> ()) {
        self.controller.add(BlockOperation {
            result(self.erase(callback))
        })
    }
    
    public func write(_ flashCartridge: FlashCartridge, progress callback: @escaping (Progress) -> (), result: @escaping (Result<(), Error>) -> ()) {
        self.controller.add(BlockOperation {
            result(self.write(flashCartridge, callback))
        })
    }
    
    private func erase(_ progress: @escaping (Progress) -> ()) -> Result<(),Error> {
        precondition(!Thread.current.isMainThread)
        //----------------------------------------------------------------------
        // Reset Flash Mode
        //----------------------------------------------------------------------
        return self.sendAndWait({ $0.flash(byte: 0xF0, at: 0x00) }, responseEvaluator: { $0!.starts(with: [0x31]) })
            //------------------------------------------------------------------
            // Read / Flush Buffer
            //------------------------------------------------------------------
            .flatMap { _ in self.read(totalBytes: 64, startingAt: 0x0000) }
            //------------------------------------------------------------------
            // Prepare for Erase
            //------------------------------------------------------------------
            .flatMap { _ in
                self.sendAndWait({
                    $0.romMode()
                    $0.pin(mode: "W")
                    $0.flash(byte: 0xAA, at: 0x555)
                })
            }
            //------------------------------------------------------------------
            // Continue preparing...
            //------------------------------------------------------------------
            .flatMap { _ in self.sendAndWait({ $0.flash(byte: 0x55, at: 0x2AA) }) }
            .flatMap { _ in self.sendAndWait({ $0.flash(byte: 0x80, at: 0x555) }) }
            .flatMap { _ in self.sendAndWait({ $0.flash(byte: 0xAA, at: 0x555) }) }
            .flatMap { _ in self.sendAndWait({ $0.flash(byte: 0x55, at: 0x2AA) }) }
            .flatMap { _ in self.sendAndWait({ $0.flash(byte: 0x10, at: 0x555) }) }
            //------------------------------------------------------------------
            // Read until '0xFF'
            //------------------------------------------------------------------
            .flatMap { _ -> Result<Data, Error> in
                self.progress = .init(totalUnitCount: -1)
                DispatchQueue.main.sync { progress(self.progress) }
                //----------------------------------------------------------------------
                defer { self.progress.resignCurrent() }
                //------------------------------------------------------
                self.progress.becomeCurrent(withPendingUnitCount: -1)
                //------------------------------------------------------
                return self.read(totalBytes: 1
                    , startingAt: 0x0000
                    , responseEvaluator: {
                        guard $0!.starts(with: [0xFF]) else {
                            self.controller.continue()
                            return false
                        }
                        return true
                }
                )
            }
            //------------------------------------------------------------------
            // Reset Flash Mode (Again)
            //------------------------------------------------------------------
            .flatMap { _ in self.sendAndWait({ $0.flash(byte: 0xF0, at: 0x00) }, responseEvaluator: { $0!.starts(with: [0x31]) }) }
            //------------------------------------------------------------------
            // Return
            //------------------------------------------------------------------
            .flatMap { _ in
                .success(())
        }
    }

    private func write(_ flashCartridge: FlashCartridge, _ progress: @escaping (Progress) -> ()) -> Result<(), Error> {
        precondition(!Thread.current.isMainThread)
        //----------------------------------------------------------------------
        self.progress = .init(totalUnitCount: Int64(flashCartridge.count))
        //----------------------------------------------------------------------
        // Reset Flash Mode
        //----------------------------------------------------------------------
        return self.sendAndWait({ $0.flash(byte: 0xF0, at: 0x00) }, responseEvaluator: { $0!.starts(with: [0x31]) })
            //------------------------------------------------------------------
            // Read / Flush Buffer
            //------------------------------------------------------------------
            .flatMap { _ in self.read(totalBytes: 64, startingAt: 0x0000) }
            //------------------------------------------------------------------
            // Prepare for Writing
            //------------------------------------------------------------------
            .flatMap { _ in FlashProgram._555.write(to: self) }
            //------------------------------------------------------------------
            // Collect the data slices of each bank in the rom
            //------------------------------------------------------------------
            .flatMap { _ in Result {
                (0..<flashCartridge.header.romBanks)
                    .map { ($0, flashCartridge.header) }
                    .map { (arg) -> (Int, Slice<FlashCartridge>) in
                        let (bank, header) = arg
                        let startIndex = bank * header.romBankSize
                        let endIndex   = startIndex.advanced(by: header.romBankSize)
                        return (bank, flashCartridge[startIndex..<endIndex])
                }
                }
            }
            //------------------------------------------------------------------
            // Write data
            //------------------------------------------------------------------
            .flatMap { (romBankSlices: [(Int, Slice<FlashCartridge>)]) in
                return Result {
                    try romBankSlices.map({ bank, slice -> Result<Data, Error> in
                        DispatchQueue.main.sync { progress(self.progress) }
                        //----------------------------------------------------------------------
                        defer { self.progress.resignCurrent() }
                        //------------------------------------------------------
                        self.progress.becomeCurrent(withPendingUnitCount: Int64(slice.count))
                        //------------------------------------------------------
                        return self.write(data: slice, prepare: {
                            $0.set(bank: bank, at: 0x2100)
                            $0.go(to: bank > 0 ? 0x4000 : 0x0000)
                        })
                    })
                    .flatMap { try $0.get() }
                }
                .map { _ in }
            }
    }
    
    private func write(data slice: Slice<FlashCartridge>, timeout: TimeInterval = -1.0, prepare: ((InsideGadgetsCartridgeController<FlashCartridge.Platform>) -> ())? = nil) -> Result<Data, Error> {
        return self.request(totalBytes: Int64(slice.count / 64)
            , timeout: timeout
            , packetSize: 1
            , prepare: {
                $0.stop()
                prepare?($0)
                let startAddress = slice.startIndex
                let bytesInRange = startAddress..<FlashCartridge.Index(startAddress + 64)
                let bytesToWrite = "T".data(using: .ascii)! + Data(slice[bytesInRange])
                $0.send(bytesToWrite)
        }
            , progress: { controller, progress in
                let startAddress = FlashCartridge.Index(progress.completedUnitCount * 64).advanced(by: Int(slice.startIndex))
                let bytesInRange = startAddress..<FlashCartridge.Index(startAddress + 64)
                let bytesToWrite = "T".data(using: .ascii)! + Data(slice[bytesInRange])
                controller.send(bytesToWrite)
        }
        )
    }
}
