import Gibby

public protocol Chipset {
    associatedtype Platform: Gibby.Platform where Platform.Cartridge.Index == Int
    
    static func erase<SerialDevice: SerialPortController>(_ serialDevice: Result<SerialDevice,Swift.Error>) -> Result<SerialDevice,Swift.Error>
    static func flash<SerialDevice>(_ serialDevice: Result<SerialDevice,Error>, cartridge: FlashCartridge<Self>, progress update: ((Progress) -> ())?) -> Result<SerialDevice,Error> where SerialDevice: SerialPortController
}

public enum ChipsetFlashProgram {
    case _555
    case _AAA
    case _555_BitSwapped
    case _AAA_BitSwapped
    case _5555
    
    public static let allFlashPrograms: [ChipsetFlashProgram] = [
        ._555,
        ._AAA,
        ._555_BitSwapped,
        ._AAA_BitSwapped,
        ._5555,
    ]
    
    internal var addressAndBytes: [(address: UInt16, byte: UInt16)] {
        switch self {
        case ._555:
            return [
                (0x555,0xAA),
                (0x2AA,0x55),
                (0x555,0x90),
            ]
        case ._AAA:
            return [
                (0xAAA,0xAA),
                (0x555,0x55),
                (0xAAA,0x90),
            ]
        case ._555_BitSwapped:
            return [
                (0x555,0xA9),
                (0x2AA,0x56),
                (0x555,0x90),
            ]
        case ._AAA_BitSwapped:
            return [
                (0xAAA,0xA9),
                (0x555,0x56),
                (0xAAA,0x90),
            ]
        case ._5555:
            return [
                (0x5555,0xAA),
                (0x2AAA,0x55),
                (0x5555,0x90),
            ]
        }
    }
}

extension Result where Success == SerialDevice<GBxCart>, Failure == Swift.Error {
    public func detectFlashID(using flashProgram: ChipsetFlashProgram) -> Result<Int,Failure> {
        self.timeout(sending: "0".bytes())
            .timeout(sending: "G\0".bytes())
            .timeout(sending: "PW\0".bytes())
            .flatMap { serialDevice in
                Result {
                    try flashProgram.addressAndBytes.forEach { (address, byte) in
                        let addressString = String(address, radix: 16, uppercase: true)
                        let byteString    = String(byte, radix: 16, uppercase: true)
                        let _: Data = try sendAndWait("0F\(addressString)\0\(byteString)\0".bytes()).get()
                    }
                    return serialDevice
                }
            }
            .sendAndWait("A0\0R".bytes())
            .flatMap { data in
                sendAndWait("0F0\0F0\0".bytes()).map { (_: Data) in
                    Int(data.hexString(separator: ""), radix: 16) ?? NSNotFound
                }
        }
    }
}

public struct FlashCartridge<C: Chipset>: Cartridge {
    public typealias Platform = C.Platform
    public typealias Index    = Platform.Cartridge.Index
    
    public init(bytes: Data) {
        self.cartridge = .init(bytes: bytes)
    }

    private let cartridge: Platform.Cartridge

    public subscript(position: Index) -> Data.Element {
        return cartridge[Index(position)]
    }
    
    public var startIndex: Index {
        return Index(cartridge.startIndex)
    }
    
    public var endIndex: Index {
        return Index(cartridge.endIndex)
    }
    
    public func index(after i: Index) -> Index {
        return Index(cartridge.index(after: i))
    }
    
    public var fileExtension: String {
        cartridge.fileExtension
    }
}

public struct AM29F016B: Chipset {
    public typealias Platform = GameboyClassic
    public static func erase<SerialDevice>(_ serialDevice: Result<SerialDevice, Error>) -> Result<SerialDevice, Swift.Error> where SerialDevice: SerialPortController {
        serialDevice
            .sendAndWait("0F0\0F0\0".bytes())
            .timeout(sending:"G".bytes())
            .timeout(sending:"PW".bytes())
            .sendAndWait("0F555\0AA\0".bytes())
            .sendAndWait("0F2AA\055\0".bytes())
            .sendAndWait("0F555\080\0".bytes())
            .sendAndWait("0F555\0AA\0".bytes())
            .sendAndWait("0F2AA\055\0".bytes())
            .sendAndWait("0F555\010\0".bytes())
            .sendAndWait("0A0\0R".bytes(),
                 packetByteSize :64,
                 isValidPacket  :{ serialDevice, data in
                    guard data!.starts(with: [0xFF]) else {
                        serialDevice.send("1".bytes(), timeout: 250)
                        return false
                    }
                    return true
            })
            .flatMap { (_: Data) in
                serialDevice
            }
            .sendAndWait("0F0\0F0\0".bytes())
    }
    
    public static func flash<SerialDevice>(_ serialDevice: Result<SerialDevice,Error>, cartridge: FlashCartridge<AM29F016B>, progress update: ((Progress) -> ())?) -> Result<SerialDevice,Error> where SerialDevice: SerialPortController {
        serialDevice
            .timeout(sending:"G".bytes())
            .timeout(sending:"PW".bytes())
            .timeout(sending:"E".bytes())
            .sendAndWait("555\0".bytes())
            .sendAndWait("AA\0".bytes())
            .sendAndWait("2AA\0".bytes())
            .sendAndWait("55\0".bytes())
            .sendAndWait("555\0".bytes())
            .sendAndWait("A0\0".bytes())
            .isTypeOf(CartKit.SerialDevice<GBxCart>.self) /* FIXME */
            .flatMap {
                flashGBxCart(.success($0), cartridge: cartridge, progress: update)
            }
            .map { $0 as! SerialDevice }
    }
    
    private static func flashGBxCart(_ serialDevice: Result<SerialDevice<GBxCart>,Error>, cartridge: FlashCartridge<AM29F016B>, progress update: ((Progress) -> ())?) -> Result<SerialDevice<GBxCart>,Error> {
        serialDevice.flashClassicCartridge(cartridge, progress: update)
    }
}


public struct AM29LV160DB: Chipset {
    public typealias Platform = GameboyClassic
    public static func erase<SerialDevice>(_ serialDevice: Result<SerialDevice, Error>) -> Result<SerialDevice, Swift.Error> where SerialDevice: SerialPortController {
        serialDevice
            .sendAndWait("0F0\0F0\0".bytes())
            .timeout(sending:"G".bytes())
            .timeout(sending:"PW".bytes())
            .sendAndWait("0FAAA\0AA\0".bytes())
            .sendAndWait("0F555\055\0".bytes())
            .sendAndWait("0FAAA\080\0".bytes())
            .sendAndWait("0FAAA\0AA\0".bytes())
            .sendAndWait("0F555\055\0".bytes())
            .sendAndWait("0FAAA\010\0".bytes())
            .sendAndWait("0A0\0R".bytes(),
                 packetByteSize :64,
                 isValidPacket  :{ serialDevice, data in
                    guard data!.starts(with: [0xFF]) else {
                        serialDevice.send("1".bytes(), timeout: 250)
                        return false
                    }
                    return true
            })
            .flatMap { (_: Data) in
                serialDevice
            }
            .sendAndWait("0F0\0F0\0".bytes())
    }
    
    public static func flash<SerialDevice>(_ serialDevice: Result<SerialDevice,Error>, cartridge: FlashCartridge<AM29LV160DB>, progress update: ((Progress) -> ())?) -> Result<SerialDevice,Error> where SerialDevice: SerialPortController {
        serialDevice
            .timeout(sending:"G".bytes())
            .timeout(sending:"PW".bytes())
            .timeout(sending:"E".bytes())
            .sendAndWait("AAA\0".bytes())
            .sendAndWait("AA\0".bytes())
            .sendAndWait("555\0".bytes())
            .sendAndWait("55\0".bytes())
            .sendAndWait("AAA\0".bytes())
            .sendAndWait("A0\0".bytes())
            .isTypeOf(CartKit.SerialDevice<GBxCart>.self) /* FIXME */
            .flatMap {
                flashGBxCart(.success($0), cartridge: cartridge, progress: update)
            }
            .map { $0 as! SerialDevice }
    }
    
    private static func flashGBxCart(_ serialDevice: Result<SerialDevice<GBxCart>,Error>, cartridge: FlashCartridge<AM29LV160DB>, progress update: ((Progress) -> ())?) -> Result<SerialDevice<GBxCart>,Error> {
        serialDevice.flashClassicCartridge(cartridge, progress: update)
    }
}

public struct ES29LV160: Chipset {
    public typealias Platform = GameboyClassic
    public static func erase<SerialDevice>(_ serialDevice: Result<SerialDevice, Error>) -> Result<SerialDevice, Swift.Error> where SerialDevice: SerialPortController {
        serialDevice
            .sendAndWait("0F0\0F0\0".bytes())
            .timeout(sending:"G".bytes())
            .timeout(sending:"PW".bytes())
            .sendAndWait("0F555\0A9\0".bytes())
            .sendAndWait("0F2AA\056\0".bytes())
            .sendAndWait("0F555\080\0".bytes())
            .sendAndWait("0F555\0A9\0".bytes())
            .sendAndWait("0F2AA\056\0".bytes())
            .sendAndWait("0F555\010\0".bytes())
            .sendAndWait("0A0\0R".bytes(),
                 packetByteSize :64,
                 isValidPacket  :{ serialDevice, data in
                    guard data!.starts(with: [0xFF]) else {
                        serialDevice.send("1".bytes(), timeout: 250)
                        return false
                    }
                    return true
            })
            .flatMap { (_: Data) in
                serialDevice
            }
            .sendAndWait("0F0\0F0\0".bytes())
    }
    
    public static func flash<SerialDevice>(_ serialDevice: Result<SerialDevice,Error>, cartridge: FlashCartridge<ES29LV160>, progress update: ((Progress) -> ())?) -> Result<SerialDevice,Error> where SerialDevice: SerialPortController {
        serialDevice
            .timeout(sending:"G".bytes())
            .timeout(sending:"PW".bytes())
            .timeout(sending:"E".bytes())
            .sendAndWait("555\0".bytes())
            .sendAndWait("A9\0".bytes())
            .sendAndWait("2AA\0".bytes())
            .sendAndWait("56\0".bytes())
            .sendAndWait("555\0".bytes())
            .sendAndWait("A0\0".bytes())
            .isTypeOf(CartKit.SerialDevice<GBxCart>.self) /* FIXME */
            .flatMap {
                flashGBxCart(.success($0), cartridge: cartridge, progress: update)
            }
            .map { $0 as! SerialDevice }
    }
    
    private static func flashGBxCart(_ serialDevice: Result<SerialDevice<GBxCart>,Error>, cartridge: FlashCartridge<ES29LV160>, progress update: ((Progress) -> ())?) -> Result<SerialDevice<GBxCart>,Error> {
        serialDevice.flashClassicCartridge(cartridge, progress: update)
    }
}
