import Gibby

extension InsideGadgetsWriter where FlashCartridge.Platform == GameboyClassic {
    enum FlashProgram {
        case _555
        case _AAA
        case _555_BIT01_SWAPPED
        case _AAA_BIT01_SWAPPED
        case _5555
        
        fileprivate var hexCodes: [(UInt16, UInt16)] {
            switch self {
            case ._555:                 return [ (0x555, 0xAA) , (0x2AA, 0x55) , (0x555, 0xA0) ]
            case ._AAA:                 return [ (0xAAA, 0xAA) , (0x555, 0x55) , (0xAAA, 0xA0) ]
            case ._555_BIT01_SWAPPED:   return [ (0x555, 0xA9) , (0x2AA, 0x56) , (0x555, 0xA0) ]
            case ._AAA_BIT01_SWAPPED:   return [ (0xAAA, 0xA9) , (0x555, 0x56) , (0xAAA, 0xA0) ]
            case ._5555:                return [ (0x5555, 0xAA) , (0x2AAA, 0x55) , (0x5555, 0xA0) ]
            }
        }
    }
    
    func set(flash program: FlashProgram, result: @escaping (Bool) -> ()) {
        let operation = SerialPortOperation(controller: self.controller, unitCount: 6, packetLength: 1, perform: { progress in
            guard progress.completedUnitCount > 0 else {
                self.controller.send("E".bytes())
                let hexCode = program.hexCodes[0].0
                self.controller.send("", number: hexCode)
                return
            }
            guard progress.completedUnitCount > 1 else {
                let hexCode = program.hexCodes[0].1
                self.controller.send("", number: hexCode)
                return
            }
            guard progress.completedUnitCount > 2 else {
                let hexCode = program.hexCodes[1].0
                self.controller.send("", number: hexCode)
                return
            }
            guard progress.completedUnitCount > 3 else {
                let hexCode = program.hexCodes[1].1
                self.controller.send("", number: hexCode)
                return
            }
            guard progress.completedUnitCount > 4 else {
                let hexCode = program.hexCodes[2].0
                self.controller.send("", number: hexCode)
                return
            }
            guard progress.completedUnitCount > 5 else {
                let hexCode = program.hexCodes[2].1
                self.controller.send("", number: hexCode)
                return
            }
        }, appendData: {
            $0.starts(with: [0x31])
        }) { data in
            result(true)
        }
        self.controller.add(operation)
    }
    
    func resetFlashMode(result: @escaping () -> ()) {
        let operation = SerialPortOperation(controller: self.controller, unitCount: 1, packetLength: 1, perform: { progress in
            guard progress.completedUnitCount > 0 else {
                self.controller.stop()
                self.controller.flash(byte: 0xF0, at: 0x00) // Reset flash back to read mode
                return
            }
        }, appendData: {
            return $0.starts(with: [0x31])
        }) { _ in
            self.controller.stop()
            result()
        }
        self.controller.add(operation)
    }
    
}
