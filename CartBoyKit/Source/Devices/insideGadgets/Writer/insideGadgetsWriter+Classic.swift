import Gibby

extension InsideGadgetsWriter where FlashCartridge == AM29F016B {
    private func setFlashMode(result: @escaping (Bool) -> ())  -> Operation {
        return SerialPortOperation(controller: self.controller, progress: Progress(totalUnitCount: 6), perform: { progress in
            guard progress.completedUnitCount > 0 else {
                self.controller.send("G".bytes(), timeout: 0)
                self.controller.send("P".bytes(), timeout: 0)
                self.controller.send("W".bytes(), timeout: 0)
                self.controller.send("E".bytes(), timeout: 0)
                self.controller.send("", number: 0x555, radix: 16, terminate: true, timeout: 0)
                return
            }
            guard progress.completedUnitCount > 1 else {
                self.controller.send("", number: 0xAA, radix: 16, terminate: true, timeout: 0)
                return
            }
            guard progress.completedUnitCount > 2 else {
                self.controller.send("", number: 0x2AA, radix: 16, terminate: true, timeout: 0)
                return
            }
            guard progress.completedUnitCount > 3 else {
                self.controller.send("", number: 0x55, radix: 16, terminate: true, timeout: 0)
                return
            }
            guard progress.completedUnitCount > 4 else {
                self.controller.send("", number: 0x555, radix: 16, terminate: true, timeout: 0)
                return
            }
            guard progress.completedUnitCount > 5 else {
                self.controller.send("", number: 0xA0, radix: 16, terminate: true, timeout: 0)
                return
            }
        }, appendData: {
            $0.starts(with: [0x31])
        }) { _ in
            print("Flash program set, 'done'")
            result(true)
        }
    }
    
    private func prepareForErase(result: @escaping (Bool) -> ())  -> Operation {
        return SerialPortOperation(controller: self.controller, progress: Progress(totalUnitCount: 6), perform: { progress in
            guard progress.completedUnitCount > 0 else {
                self.controller.send("F555\0AA\0".bytes(), timeout: 0)
                return
            }
            guard progress.completedUnitCount > 1 else {
                self.controller.send("F2AA\055\0".bytes(), timeout: 0)
                return
            }
            guard progress.completedUnitCount > 2 else {
                self.controller.send("F555\080\0".bytes(), timeout: 0)
                return
            }
            guard progress.completedUnitCount > 3 else {
                self.controller.send("F555\0AA\0".bytes(), timeout: 0)
                return
            }
            guard progress.completedUnitCount > 4 else {
                self.controller.send("F2AA\055\0".bytes(), timeout: 0)
                return
            }
            guard progress.completedUnitCount > 5 else {
                self.controller.send("F555\010\0".bytes(), timeout: 0)
                return
            }
        }, appendData: {
            $0.starts(with: [0x31])
        }) { _ in
            print("Prepare for erase, 'done'")
            result(true)
        }
    }
    
    public func erase(result: @escaping (Bool) -> ())  -> Operation {
        var buffer = Data()
        var sectorCount = 0
        let read64Bytes = SerialPortOperation(controller: self.controller, progress: Progress(totalUnitCount: 6), perform: { progress in
            guard progress.completedUnitCount > 0 else {
                buffer.removeAll()
                self.controller.send("0".bytes(), timeout: 0)
                self.controller.send("A0\0".bytes(), timeout: 250)
                self.controller.send("R".bytes(), timeout: 0)
                return
            }
        }, appendData: {
            buffer.append($0)
            if buffer.count >= 64 {
                return true
            }
            return false
        }) { _ in
            buffer.removeAll()
            print("Read 64 bytes, 'done'")
            self.controller.send("0".bytes(), timeout: 250)
        }
        
        let prepErase = prepareForErase { _ in print("Now erasing...") }
        prepErase.addDependency(read64Bytes)

        defer {
            read64Bytes.start()
            prepErase.start()
        }
        
        let erase = SerialPortOperation(controller: controller, progress: Progress(totalUnitCount: 6)
            , perform: { progress in
            guard progress.completedUnitCount > 0 else {
                self.controller.send("A0\0".bytes(), timeout: 250)
                self.controller.send("R".bytes(), timeout: 0)
                return
            }
            guard progress.completedUnitCount % 64 == 0 else {
                return
            }
            self.controller.send("1".bytes(), timeout: 0)
        }, appendData: { data in
            buffer += data
            // Don't stop reading until we receive '0xFF' as the first byte.
            guard buffer.starts(with: [0xFF]), buffer.count == 64 else {
                // Wait for 'buffer' to fill with 64 bytes
                guard buffer.count % 64 == 0 else {
                    return false
                }
                // Reset 'buffer' and update metrics (sector count)
                buffer.removeAll()
                sectorCount += 1
                if sectorCount % 20000 == 0 {
                    print("'Erase' is running long. \(sectorCount)")
                }
                
                // Continue to read the next 64 bytes...
                self.controller.send("1".bytes(), timeout: 0)
                
                // Returning 'false' means we haven't received 0xFF as a byte
                return false
            }
            return true
        }
        ) { _ in
            print(NSString(string: #file).lastPathComponent, #function)
            print("\(AM29F016B.self) erased \(sectorCount) sectors")
            result(true)
        }

        erase.addDependency(prepErase)
        print("Erasing \(AM29F016B.self)")
        return erase
    }
    
    public func write(_ flashCartridge: FlashCartridge, result: @escaping (Bool) -> ()) -> Operation {
        let header = flashCartridge.header
        print(header)
        guard header.isLogoValid, header.romBankSize != 0 else {
            return BlockOperation {
                result(false)
            }
        }
        let write = SerialPortOperation(controller: self.controller, progress: Progress(totalUnitCount: Int64(header.romSize / 64)), perform: { progress in
            guard progress.completedUnitCount > 0 else {
                print("Begin writing ROM: \(header.title)")
                self.controller.send("0".bytes(), timeout: 0)
                self.controller.send("A0\0".bytes(), timeout: 250)
                self.controller.send("T".data(using: .ascii)! + flashCartridge[..<64], timeout: 0)
                return
            }
            let startAddress = Int(progress.completedUnitCount * 64)
            let range = startAddress..<Int(startAddress + 64)
            if case let bank = startAddress / header.romBankSize, bank > 0, startAddress % header.romBankSize == 0 {
                print("#\(bank), \(progress.fractionCompleted)%")
                self.controller.send("0".bytes(), timeout: 100)
                self.controller.send("B", number: 0x2100, radix: 16, terminate: true, timeout: 0)
                self.controller.send("B", number: bank, radix: 10, terminate: true, timeout: 0)
                if bank >= 0x100 {
                    self.controller.send("B", number: 0x3000, radix: 16, terminate: true, timeout: 0)
                    self.controller.send("B", number: 1, radix: 10, terminate: true, timeout: 0)
                }
                
                self.controller.send("A4000\0".bytes(), timeout: 250)
                self.controller.send("B", number: 0x4000, radix: 16, terminate: true, timeout: 0)
                self.controller.send("B", number: bank, radix: 10, terminate: true, timeout: 0)
                self.controller.send("T".data(using: .ascii)! + flashCartridge[range], timeout: 0)
            }
            else {
                self.controller.send("T".data(using: .ascii)! + flashCartridge[range], timeout: 0)
            }
        }) { _ in
            print("Writing flash cart, 'done'")
            self.controller.send("0".bytes(), timeout: 0)
            result(true)
        }
        
        let setFlashMode = self.setFlashMode { _ in }
        write.addDependency(setFlashMode)
        setFlashMode.start()
        return write
    }
}
