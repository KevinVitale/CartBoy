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
            case ._555:                 return [  (0x555, 0xAA) ,  (0x2AA, 0x55) ,  (0x555, 0xA0) ]
            case ._AAA:                 return [  (0xAAA, 0xAA) ,  (0x555, 0x55) ,  (0xAAA, 0xA0) ]
            case ._555_BIT01_SWAPPED:   return [  (0x555, 0xA9) ,  (0x2AA, 0x56) ,  (0x555, 0xA0) ]
            case ._AAA_BIT01_SWAPPED:   return [  (0xAAA, 0xA9) ,  (0x555, 0x56) ,  (0xAAA, 0xA0) ]
            case ._5555:                return [ (0x5555, 0xAA) , (0x2AAA, 0x55) , (0x5555, 0xA0) ]
            }
        }
        
        func write(to writer: InsideGadgetsWriter<FlashCartridge>) -> (Result<Data, Error>) {
            return writer
                .sendAndWait({
                    $0.romMode()
                    $0.pin(mode: "W")
                    $0.send("E".bytes())
                    $0.send("", number: self.hexCodes[0].0)
                } , responseEvaluator: {
                    $0!.starts(with: [0x31])
                })
                .flatMap { _ in writer
                    .sendAndWait({ $0.send("", number: self.hexCodes[0].1) }, responseEvaluator: { $0!.starts(with: [0x31]) })
                }
                .flatMap { _ in writer
                    .sendAndWait({ $0.send("", number: self.hexCodes[1].0) }, responseEvaluator: { $0!.starts(with: [0x31]) })
                }
                .flatMap { _ in writer
                    .sendAndWait({ $0.send("", number: self.hexCodes[1].1) }, responseEvaluator: { $0!.starts(with: [0x31]) })
                }
                .flatMap { _ in writer
                    .sendAndWait({ $0.send("", number: self.hexCodes[2].0) }, responseEvaluator: { $0!.starts(with: [0x31]) })
                }
                .flatMap { _ in writer
                    .sendAndWait({ $0.send("", number: self.hexCodes[2].1) }, responseEvaluator: { $0!.starts(with: [0x31]) })
            }
        }
    }
}
