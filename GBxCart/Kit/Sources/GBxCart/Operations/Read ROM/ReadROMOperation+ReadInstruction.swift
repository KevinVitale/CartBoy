import Gibby

extension ReadROMOperation {
    public enum MemoryRange {
        case header(GameBoy)
        case range(Range<Int>)
        case rom(header: ROMHeader)

        var bytesToRead: Int {
            switch self {
            case .header(let gameBoy):
                return gameBoy.headerSize
            case .range(let range):
                return range.count
            case .rom(let header):
                return header.romSize
            }
        }
        
        var startingAddress: Int {
            switch self {
            case .header(let gameBoy):
                return gameBoy.headerOffset
            case .range(let range):
                return range.lowerBound
            case .rom:
                return 0
            }
        }
        
        var indices: Range<Int> {
            switch self {
            case .header:
                return 0..<bytesToRead
            case .range(let range):
                return range.indices
            case .rom(let header):
                return 0..<header.romSize
            }
        }
    }
}

/* TODO: Move to 'Gibby' */
public struct ROMHeader {
    public init?(gameBoy system: GameBoy, bytes: Data) {
        guard bytes.count == system.headerSize else {
            return nil
        }
        self.system = system
        self.bytes  = bytes
    }
    
    private let system: GameBoy
    private let  bytes: Data
}

extension ROMHeader {
    public var bootInstructions: Data {
        guard system != .advance else {
            fatalError("GBA not yet implemented.")
        }
        return bytes[0x0..<0x4]
    }
    
    public var isLogoValid: Bool {
        switch system {
        case .original: fallthrough
        case    .color: return bytes[0x4..<0x34] == system.logo
        case  .advance: return false
        }
    }
    
    public var title: String {
        guard system != .advance else {
            fatalError("GBA not yet implemented.")
        }
        
        var title = Data(bytes[0x34..<0x44])

        // Portions of 'title' got re-purposed by BigN post-GBC
        switch self.isColorOnly {
        case true?:
            title = title[0..<11]
        default:
            if self.manufacturer?.contains(" ") ?? false {
                title = title[..<15]
            }
        }
        
        return String(data: title.filter { $0 != 0 }, encoding: .ascii)!
    }
    
    public var manufacturer: String? {
        guard system != .advance else {
            return nil
        }
        
        return String(data: bytes[0x3F..<0x43], encoding: .ascii)
    }
    
    private var colorFlag: UInt8? {
        guard system != .advance else {
            return nil
        }
        return bytes[0x43]
    }
    
    public var isColorOnly: Bool? {
        guard system != .advance else {
            return nil
        }
        
        guard colorFlag != 0x0 else {
            return nil
        }
        
        return colorFlag == 0xC0
    }
    
    public var licensee: String {
        let value = bytes[0x44..<0x46]
            .reversed()
            .reduce(into: UInt8()) { result, next in
                guard result != 0 else {
                    result = next
                    return
                }
                result -= next
        }
        
        return String(value, radix: 10, uppercase: true)
    }

    public var supportsSuperGameBoy: Bool? {
        guard system != .advance else {
            return nil
        }
        return bytes[0x46] == 0x03
    }
    
    public var config: MemoryController.Configuration {
        switch system {
        case .original: fallthrough
        case    .color: return .init(rawValue: bytes[0x47])
        case  .advance: return .unknown(value: 0)
        }
    }
    
    public var romSize: Int {
        switch system {
        case .original: fallthrough
        case    .color: return 0
        case  .advance: return 0
        }
    }

    public var romSizeID: UInt8 {
        switch system {
        case .original: fallthrough
        case    .color: return bytes[0x48]
        case  .advance: return 0
        }
    }
    
    public var ramSize: Int {
        switch system {
        case .original: fallthrough
        case    .color: return 0
        case  .advance: return 0
        }
    }
    
    public var ramSizeID: UInt8 {
        switch system {
        case .original: fallthrough
        case    .color: return bytes[0x49]
        case  .advance: return 0
        }
    }
    
    public var region: String {
        return (bytes[0x4A] == 0x01) ? "Non-Japanese" : "Japanese"
    }
    
    public var legacyLicensee: UInt8? {
        guard system != .advance else {
            return nil
        }
        
        let value = bytes[0x4B]
        
        guard value != 0x33 else {
            /* New License Code */
            return nil
        }
        
        return value
    }
    
    public var version: UInt8 {
        guard system != .advance else {
            return 0x0
        }
        
        return bytes[0x4C]
    }
    
    public var headerChecksum: String {
        return String(bytes[0x4D], radix: 16, uppercase: true)
    }
    
    public var cartChecksum: String {
        return bytes[0x4E..<0x50].reversed().map { String($0, radix: 16, uppercase: true)}.joined()
    }
}
