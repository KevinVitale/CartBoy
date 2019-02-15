import Gibby

extension ReadROMOperation {
    public enum MemoryRange {
        case header
        case range(Range<Int>)
        case rom(header: Cartridge.Header)

        var bytesToRead: Int {
            switch self {
            case .header:
                return Int(Gameboy.headerSize)
            case .range(let range):
                return range.count
            case .rom(let header):
                return header.romSize
            }
        }
        
        var startingAddress: Int {
            switch self {
            case .header:
                return Int(Gameboy.headerOffset)
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
