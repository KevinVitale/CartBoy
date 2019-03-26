import Gibby

extension InsideGadgetsWriter where FlashCartridge == AM29F016B {
    private static func setFlashMode<Controller>(using controller: Controller, result: @escaping (Bool) -> ())  -> Operation where Controller: SerialPortController {
        return SerialPortOperation(controller: controller, progress: Progress(totalUnitCount: 6), perform: { progress in
            guard progress.completedUnitCount > 0 else {
                controller.send("G".bytes(), timeout: 0)
                controller.send("P".bytes(), timeout: 0)
                controller.send("W".bytes(), timeout: 0)
                
                controller.send("E".bytes(), timeout: 0)
                controller.send("", number: 0x555, radix: 16, terminate: true, timeout: 0)
                controller.send("", number: 0xAA, radix: 16, terminate: true, timeout: 0)
                controller.send("", number: 0x2AA, radix: 16, terminate: true, timeout: 0)
                controller.send("", number: 0x55, radix: 16, terminate: true, timeout: 0)
                controller.send("", number: 0x555, radix: 16, terminate: true, timeout: 0)
                controller.send("", number: 0xA0, radix: 16, terminate: true, timeout: 0)
                return
            }
        }) { _ in
            controller.send("0\0".bytes(), timeout: 0)
            result(true)
        }
    }
    
    private static func prepareForErase<Controller>(using controller: Controller, result: @escaping (Bool) -> ())  -> Operation where Controller: SerialPortController {
        return SerialPortOperation(controller: controller, progress: Progress(totalUnitCount: 6), perform: { progress in
            guard progress.completedUnitCount > 0 else {
                controller.send("F555\0AA\0".bytes(), timeout: 0)
                controller.send("F2AA\055\0".bytes(), timeout: 0)
                controller.send("F555\080\0".bytes(), timeout: 0)
                controller.send("F555\0AA\0".bytes(), timeout: 0)
                controller.send("F2AA\055\0".bytes(), timeout: 0)
                controller.send("F555\010\0".bytes(), timeout: 0)
                return
            }
        }) { _ in
            controller.send("0\0".bytes(), timeout: 0)
            result(true)
        }
    }
    
    public static func erase<Controller>(using controller: Controller, result: @escaping (Bool) -> ())  -> Operation where Controller: SerialPortController {
        let prep = setFlashMode(using: controller) { _ in
            print("Set Flash Mode Complete")
        }
        let sendErase = prepareForErase(using: controller) { _ in
            print("Prep Erase Complete")
        }
        sendErase.addDependency(prep)
        
        var buffer = Data()
        var sectorCount = 0
        let erase = SerialPortOperation(controller: controller, progress: Progress(totalUnitCount: 6)
            , perform: { progress in
            guard progress.completedUnitCount > 0 else {
                controller.send("A0\0".bytes(), timeout: 0)
                controller.send("R".bytes(), timeout: 0)
                return
            }
            guard progress.completedUnitCount % 64 == 0 else {
                return
            }
            controller.send("1".bytes(), timeout: 0)
        }, appendData: { data in
            buffer += data
            // Don't stop reading until we receive '0xFF' as the first byte.
            guard buffer.starts(with: [0xFF]) else {
                // Wait for 'buffer' to fill with 64 bytes
                guard buffer.count % 64 == 0 else {
                    return false
                }
                // Reset 'buffer' and update metrics (sector count)
                buffer.removeAll()
                sectorCount += 1
                
                // Continue to read the next 64 bytes...
                controller.send("1".bytes(), timeout: 0)
                
                // Returning 'false' means we haven't received 0xFF as a byte
                return false
            }
            return true
        }
        ) { _ in
            print("\(AM29F016B.self) erased \(sectorCount) sectors")
            controller.send("0\0".bytes(), timeout: 250)
            result(true)
        }
        
        erase.addDependency(sendErase)
        prep.start()
        
        print("Erasing \(AM29F016B.self)")
        sendErase.start()
        return erase
    }
    
    public func write<Controller>(flashCartridge: FlashCartridge, using controller: Controller, result: @escaping (Bool) -> ()) -> Operation where Controller : SerialPortController {
        let prep = InsideGadgetsWriter<AM29F016B>.setFlashMode(using: controller) { _ in
            print("Set Flash Mode Complete")
        }
        let data = Data(flashCartridge[flashCartridge.startIndex..<flashCartridge.endIndex])
        let header = flashCartridge.header
        print(header)
        let write = SerialPortOperation(controller: controller, progress: Progress(totalUnitCount: Int64(header.romSize / 64)), perform: { progress in
            guard progress.completedUnitCount > 0 else {
                controller.send("0".bytes(),  timeout: 0)
                controller.send("B", number: 0x0000, radix: 16, terminate: true, timeout: 0)
                controller.send("B", number: 000000, radix: 10, terminate: true, timeout: 0)
                controller.send("A0\0".bytes(), timeout: 250)
                controller.send("T".data(using: .ascii)! + data[..<64], timeout: 0)
                return
            }
            let startAddress = Int(progress.completedUnitCount * 64)
            let range = startAddress..<Int(startAddress + 64)
            if case let bank = startAddress / header.romBankSize, bank > 1, startAddress % header.romBankSize == 0 {
                print("#\(bank), \(progress.fractionCompleted)%")
                controller.send("0".bytes(), timeout: 0)
                controller.send("B", number: 0x2100, radix: 16, terminate: true, timeout: 0)
                controller.send("B", number: bank, radix: 10, terminate: true, timeout: 0)
                if bank >= 0x100 {
                    controller.send("B", number: 0x3000, radix: 16, terminate: true, timeout: 0)
                    controller.send("B", number: 1, radix: 10, terminate: true, timeout: 0)
                }
                
                controller.send("A4000\0".bytes(), timeout: 250)
                controller.send("B", number: 0x4000, radix: 16, terminate: true, timeout: 0)
                controller.send("B", number: bank, radix: 10, terminate: true, timeout: 0)
                controller.send("T".data(using: .ascii)! + data[range], timeout: 0)
            }
            else {
                controller.send("T".data(using: .ascii)! + data[range], timeout: 0)
            }
        }) { _ in
            print("Flash Cart Write Complete")
            controller.send("0\0".bytes(), timeout: 0)
            result(true)
        }
        
        write.addDependency(prep)
        prep.start()
        return write
    }
}
