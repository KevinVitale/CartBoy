import Gibby

extension ReadROMOperation {
    public enum MemoryRange {
        case header
        case range(Range<Int>)
        case cartridge(Cartridge.Header)

        var bytesToRead: Int {
            switch self {
            case .header:
                return Int(Gameboy.headerSize)
            case .range(let range):
                return range.count
            case .cartridge(let header):
                return header.romSize
            }
        }
        
        var startingAddress: Int {
            switch self {
            case .header:
                return Int(Gameboy.headerOffset)
            case .range(let range):
                return range.lowerBound
            case .cartridge:
                return 0
            }
        }
        
        var indices: Range<Int> {
            return 0..<bytesToRead
        }
    }
}
