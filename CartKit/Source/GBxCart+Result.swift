import Gibby

extension Result where Success == SerialDevice<GBxCart>, Failure == Swift.Error {
    /**
     * Reads 64 bytes (starting at address `0x0`), then stops.
     *
     * - parameter platform: Either `GameboyClassic`, or `GameboyAdvance`.
     * - note: The `Data` read is discarded.
     * - returns: A `Result` which retains `SerialDevice<GBxCart>` as its `Success`.
     */
    func flush<Platform: Gibby.Platform>(forPlatform platform: Platform.Type) -> Result<Success,Failure> {
        flatMap { serialDevice in
            read(byteCount: 64) { serialDevice, progress in
                guard progress.isFinished == false else {
                    serialDevice.send("0\0".bytes())
                    return
                }
                serialDevice.seek(toAddress: 0)
                serialDevice.startReading(forPlatform: platform)
            }
            .map { _ in serialDevice }
        }
    }
}

extension Result where Success == SerialDevice<GBxCart>, Failure == Swift.Error {
    /**
     *
     */
    private func readGameboyClassic<Number: FixedWidthInteger>(bank: Number, header: GameboyClassic.Header, progress update: ((Progress) -> ())? = nil) -> Result<Data,Failure> {
        read(byteCount: header.romBankSize) { serialDevice, progress in
            if progress.completedUnitCount == 0 {
                serialDevice.send("0\0".bytes())
                if bank > 0 {
                    if case .one = header.configuration {
                        serialDevice.setBank(0,           at: 0x6000)
                        serialDevice.setBank(bank >> 5,   at: 0x4000)
                        serialDevice.setBank(bank & 0x1F, at: 0x2000)
                    }
                    else {
                        serialDevice.setBank(bank, at: 0x2100)
                        if bank > 0x100 {
                            serialDevice.setBank(1, at: 0x3000)
                        }
                    }
                }
                serialDevice.seek(toAddress: bank > 0 ? 0x4000 : 0)
                serialDevice.startReading(forPlatform: GameboyClassic.self)
            }
            else if progress.isFinished {
                serialDevice.send("0\0".bytes())
            }
            else {
                update?(progress)
                serialDevice.send("1".bytes())
            }
        }
    }
    
    /**
     *
     */
    internal func readClassicCartridge(forHeader header: GameboyClassic.Header, progress update: ((Progress) -> ())? = nil) -> Result<GameboyClassic.Cartridge,Failure> {
        var cartData = Data(capacity: header.romSize)
        let progress = Progress(totalUnitCount: Int64(header.romSize))
        for bank in 0..<header.romBanks {
            do {
                // MB2 Fix -----------------------------------------------------
                if case .two = header.configuration {
                    let _ = try flush(forPlatform: GameboyClassic.self).get()
                }

                // Begin Progress ----------------------------------------------
                progress.becomeCurrent(withPendingUnitCount: Int64(header.romBankSize))
                
                // Read Bank Data ----------------------------------------------
                cartData += try readGameboyClassic(bank: bank, header: header, progress: { _ in
                    DispatchQueue.main.async { update?(progress) }
                }).get()
                
                // End Progress ------------------------------------------------
                progress.resignCurrent()
            } catch {
                return .failure(error)
            }
        }
        return Result<Data,Failure>
            .success(cartData)
            .map(GameboyClassic.Cartridge.init)
            .checkHeader()
    }
    
    /**
     *
     */
    internal func readAdvancedCartridge(forHeader header: GameboyAdvance.Header, progress update: ((Progress) -> ())? = nil) -> Result<GameboyClassic.Cartridge,Failure> {
        .failure(SerialDeviceError.platformNotSupported(GameboyAdvance.self))
    }
}
    
extension Result where Success == SerialDevice<GBxCart>, Failure == Swift.Error {
    /**
     *
     */
    private func readGameboyClassic<Number: FixedWidthInteger>(saveBank bank: Number, header: GameboyClassic.Header, progress update: ((Progress) -> ())? = nil) -> Result<Data,Failure> {
        read(byteCount: header.ramBankSize) { serialDevice, progress in
            if progress.completedUnitCount == 0 {
                serialDevice.send("0\0".bytes())
                // SET: the 'RAM' mode (MBC1-ONLY) -----------------------------
                if case .one = header.configuration {
                    serialDevice.setBank(1, at: 0x6000)
                }
                // SET: 'RAM' enabled ------------------------------------------
                serialDevice.setBank(0x0A, at: 0x0000)

                // SET: start address ------------------------------------------
                serialDevice.setBank(bank, at: 0x4000)
                serialDevice.seek(toAddress: 0xA000)
                
                // SET: cart mode ----------------------------------------------
                serialDevice.send("G".bytes())
                
                // Start -------------------------------------------------------
                serialDevice.startReading(forPlatform: GameboyClassic.self)
            }
            else if progress.isFinished {
                serialDevice.send("0\0".bytes())
                
                // SET: 'RAM' disabled -----------------------------------------
                serialDevice.setBank(0x00, at: 0x0000)
            }
            else {
                update?(progress)
                serialDevice.send("1".bytes())
            }
        }
    }
    
    /**
     *
     */
    internal func readClassicCartridgeSaveData(forHeader header: GameboyClassic.Header, progress update: ((Progress) -> ())? = nil) -> Result<Data,Failure> {
        var saveData = Data(capacity: header.ramSize)
        let progress = Progress(totalUnitCount: Int64(header.ramSize))
        for bank in 0..<header.ramBanks {
            do {
                // MB2 Fix -----------------------------------------------------
                if case .two = header.configuration {
                    let _ = try flush(forPlatform: GameboyClassic.self).get()
                }
                
                // Begin Progress ----------------------------------------------
                progress.becomeCurrent(withPendingUnitCount: Int64(header.ramBankSize))
                
                // Read Bank Data ----------------------------------------------
                saveData += try readGameboyClassic(saveBank: bank, header: header, progress: { _ in
                    DispatchQueue.main.async { update?(progress) }
                }).get()
                
                // End Progress ------------------------------------------------
                progress.resignCurrent()
                
            }
            catch {
                return .failure(error)
            }
        }
        
        return .success(saveData)
    }
}

extension Result where Success == SerialDevice<GBxCart>, Failure == Swift.Error {
    /**
     *
     */
    private func restoreClassicCartridge<Number: FixedWidthInteger>(
        saveBank bank   :Number,
        saveData        :Data,
        header          :GameboyClassic.Header,
        progress update :((Progress) -> ())? = nil
    ) -> Result<(),Failure> {
        write(numberOfConfirmations: saveData.count / 64) { serialDevice, progress in
            if progress.completedUnitCount == 0 {
                serialDevice.send("0\0".bytes())
                // SET: the 'RAM' mode (MBC1-ONLY) -----------------------------
                if case .one = header.configuration {
                    serialDevice.setBank(1, at: 0x6000)
                }
                // SET: 'RAM' enabled ------------------------------------------
                serialDevice.setBank(0x0A, at: 0x0000)
                
                // SET: start address ------------------------------------------
                serialDevice.setBank(bank, at: 0x4000)
                serialDevice.seek(toAddress: 0xA000)
                
                let dataToWrite = saveData[saveData.startIndex..<saveData.startIndex.advanced(by: 64)]
                serialDevice.send("W".data(using: .ascii)! + dataToWrite)
            }
            else if progress.isFinished {
                serialDevice.send("0\0".bytes())
                
                // SET: 'RAM' disabled -----------------------------------------
                serialDevice.setBank(0x00, at: 0x0000)
            }
            else {
                update?(progress)
                let startAddress = Int(progress.completedUnitCount * 64).advanced(by: saveData.startIndex)
                let rangeOfBytes = startAddress..<Int(startAddress + 64)
                let dataToWrite  = saveData[rangeOfBytes]
                serialDevice.send("W".data(using: .ascii)! + dataToWrite)
            }
        }
        .map { _ in () }
    }
    
    /**
     *
     */
    internal func restoreClassicCartridgeSaveData(_ saveData: Data, forHeader header: GameboyClassic.Header, progress update: ((Progress) -> ())? = nil) -> Result<(),Failure> {
        let progress = Progress(totalUnitCount: Int64(header.ramSize))
        for bank in 0..<header.ramBanks {
            let startIndex = bank * header.ramBankSize
            let endIndex   = startIndex.advanced(by: header.ramBankSize)
            //------------------------------------------------------------------
            do {
                // MB2 Fix -----------------------------------------------------
                if case .two = header.configuration {
                    let _ = try flush(forPlatform: GameboyClassic.self).get()
                }
                
                // Begin Progress ----------------------------------------------
                progress.becomeCurrent(withPendingUnitCount: Int64(header.ramBankSize))
                
                // Read Bank Data ----------------------------------------------
                try restoreClassicCartridge(saveBank: bank, saveData: saveData[startIndex..<endIndex], header: header, progress: { _ in
                    DispatchQueue.main.async { update?(progress) }
                }).get()
                
                // End Progress ------------------------------------------------
                progress.resignCurrent()
                
            }
            catch {
                return .failure(error)
            }
        }
        
        return .success(())
    }
}

extension Result where Success == SerialDevice<GBxCart>, Failure == Swift.Error {
    /**
     *
     */
    private func writeClassicCartridge<C: Chipset, Number: FixedWidthInteger>(
        bank            :Number,
        romData         :Slice<FlashCartridge<C>>,
        header          :GameboyClassic.Header,
        progress update :((Progress) -> ())? = nil
    ) -> Result<(),Failure> {
        write(numberOfConfirmations: romData.count / 64) { serialDevice, progress in
            if progress.completedUnitCount == 0 {
                serialDevice.send("0\0".bytes())
                
                // SET: start address ------------------------------------------
                serialDevice.setBank(bank, at: 0x2100)
                serialDevice.seek(toAddress: bank > 0 ? 0x4000 : 0x0000)
                
                let dataToWrite = romData[romData.startIndex..<romData.startIndex.advanced(by: 64)]
                serialDevice.send("T".data(using: .ascii)! + dataToWrite)
            }
            else if progress.isFinished {
                serialDevice.send("0\0".bytes())
                
                // SET: 'RAM' disabled -----------------------------------------
                serialDevice.setBank(0x00, at: 0x0000)
            }
            else {
                update?(progress)
                let startAddress = Int(progress.completedUnitCount * 64).advanced(by: romData.startIndex)
                let rangeOfBytes = startAddress..<Int(startAddress + 64)
                let dataToWrite  = romData[rangeOfBytes]
                serialDevice.send("T".data(using: .ascii)! + dataToWrite)
            }
        }
        .map { _ in () }
    }
    
    /**
     *
     */
    internal func flashClassicCartridge<C: Chipset>(_ flashCartridge: FlashCartridge<C>, progress update: ((Progress) -> ())? = nil) -> Result<Success,Failure> where C.Platform == GameboyClassic {
        let header = flashCartridge.header
        let progress = Progress(totalUnitCount: Int64(flashCartridge.count))
        for bank in 0..<header.romBanks {
            let startIndex = bank * header.romBankSize
            let endIndex   = startIndex.advanced(by: header.romBankSize)
            //------------------------------------------------------------------
            do {
                // MB2 Fix -----------------------------------------------------
                if case .two = header.configuration {
                    let _ = try flush(forPlatform: GameboyClassic.self).get()
                }
                
                // Begin Progress ----------------------------------------------
                progress.becomeCurrent(withPendingUnitCount: Int64(header.romBankSize))
                
                // Read Bank Data ----------------------------------------------
                try writeClassicCartridge(bank: bank, romData: flashCartridge[startIndex..<endIndex], header: header, progress: { _ in
                    DispatchQueue.main.async { update?(progress) }
                }).get()
                
                // End Progress ------------------------------------------------
                progress.resignCurrent()
            } catch {
                return .failure(error)
            }
        }
        return self
    }
}

extension Result where Success == SerialDevice<GBxCart>, Failure == Swift.Error {
    /**
     *
     */
    internal func setVoltage(_ voltage: Voltage) -> Result<Success,Failure> {
        timeout(sending: voltage.bytes)
    }
    
    /**
     *
     */
    internal func setVoltage<Platform: Gibby.Platform>(forPlatform platform: Platform.Type) -> Result<Success,Failure> {
        readPCBVersion().flatMap { version in
            guard version > 2 else {
                return self
            }
            
            switch platform {
            case is GameboyClassic.Type :return setVoltage(.high).flatMap { _ in self }
            case is GameboyAdvance.Type :return setVoltage( .low).flatMap { _ in self }
            default: return self
            }
        }
    }
}
