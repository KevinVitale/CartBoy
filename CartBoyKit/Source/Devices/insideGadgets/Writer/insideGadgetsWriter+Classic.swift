import Gibby

extension InsideGadgetsWriter where FlashCartridge == AM29F016B {
    private func prepareForErase(result: @escaping (Bool) -> ()) {
        let operation = SerialPortOperation(controller: self.controller, unitCount: 6, packetLength: 1, perform: { progress in
            guard progress.completedUnitCount > 0 else {
                print("Preparing: sending 'Erase' bytes...")
                self.controller.break(timeout: 250)
                self.controller.romMode()
                self.controller.pin(mode: "W")
                self.controller.flash(byte: 0xAA, at: 0x555)
                return
            }
            guard progress.completedUnitCount > 1 else {
                self.controller.flash(byte: 0x55, at: 0x2AA)
                return
            }
            guard progress.completedUnitCount > 2 else {
                self.controller.flash(byte: 0x80, at: 0x555)
                return
            }
            guard progress.completedUnitCount > 3 else {
                self.controller.flash(byte: 0xAA, at: 0x555)
                return
            }
            guard progress.completedUnitCount > 4 else {
                self.controller.flash(byte: 0x55, at: 0x2AA)
                return
            }
            guard progress.completedUnitCount > 5 else {
                self.controller.flash(byte: 0x10, at: 0x555)
                return
            }
        }, appendData: {
            $0.starts(with: [0x31])
        }) { data in
            self.controller.stop(timeout: 250)
            result(true)
        }
        self.controller.add(operation)
    }
    
    public func erase(result: @escaping (Bool) -> ()) {
        let operation = BlockOperation { [weak self] in
            let group = DispatchGroup()
            //------------------------------------------------------------------
            group.enter()
            self?.resetFlashMode {
                group.leave()
            }
            //------------------------------------------------------------------
            group.enter()
            self?.read(64, at: 0x0000) { _ in
                group.leave()
            }
            //------------------------------------------------------------------
            group.enter()
            self?.prepareForErase { _ in
                group.leave()
            }
            group.wait()
            //------------------------------------------------------------------
            group.enter()
            var finished = false
            self?.resetProgress(to: 1)
            self?.read(1, at: 0x0, appendData: { data in
                guard data.starts(with: [0xFF]) else {
                    self?.controller.continue()
                    return false
                }
                return true
            }) { _ in
                if !finished {
                    group.leave()
                }
                finished.toggle()
            }
            group.wait()
            //------------------------------------------------------------------
            group.enter()
            self?.resetFlashMode {
                group.leave()
            }
            group.wait()
            //------------------------------------------------------------------
            defer { self?.resetProgress(to: 0) }
            result(true)
        }
        self.controller.add(operation)
    }
    
    public func write(_ flashCartridge: FlashCartridge, result: @escaping (Bool) -> ()) {
        self.controller.add(BlockOperation { [weak self] in
            let group = DispatchGroup()
            //------------------------------------------------------------------
            group.enter()
            self?.resetFlashMode {
                group.leave()
            }
            group.wait()
            //------------------------------------------------------------------
            group.enter()
            self?.read(64, at: 0x0000) { _ in
                group.leave()
            }
            group.wait()
            //--------------------------------------------------------------
            self?.controller.romMode()
            self?.controller.pin(mode: "W")
            //--------------------------------------------------------------
            group.enter()
            self?.set(flash: ._555) { _ in
                group.leave()
            }
            group.wait()
            //--------------------------------------------------------------
            let header = flashCartridge.header
            //------------------------------------------------------------------
            self?.resetProgress(to: Int64(flashCartridge.header.romSize / 64))
            //------------------------------------------------------------------
            for bank in 0..<header.romBanks {
                //--------------------------------------------------------------
                let startAddress = UInt16(bank > 0 ? 0x4000 : 0x0000)
                let lowerBound   = Int(startAddress) * bank
                let bytesInRange = lowerBound..<lowerBound + header.romBankSize
                let bytesToWrite = flashCartridge[bytesInRange]
                //--------------------------------------------------------------
                group.enter()
                //--------------------------------------------------------------
                self?.write(bytesToWrite, at: startAddress, prepare: {
                    if bank > 0 {
                        $0.set(bank: bank, at: 0x2100)
                        if bank >= 0x100 {
                            $0.set(bank: 1, at: 0x3000)
                        }
                    }
                    $0.go(to: startAddress)
                    $0.set(bank: bank, at: 0x4000)
                }) {
                    group.leave()
                }
            }
            //------------------------------------------------------------------
            group.wait()
            //------------------------------------------------------------------
            group.enter()
            self?.resetFlashMode {
                group.leave()
            }
            group.wait()
            //------------------------------------------------------------------
            defer { self?.resetProgress(to: 0) }
            result(true)
        })
    }
}
