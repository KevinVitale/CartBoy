import Gibby

extension ReadROMOperation {
    public enum MemoryRange: CustomDebugStringConvertible {
        case header
        case range(Range<Int>)
        case cartridge(Cartridge.Header)
        
        public var debugDescription: String {
            switch self {
            case .header: return "MemoryRange.Header"
            case .range: return "MemoryRange.Range"
            case .cartridge: return "MemoryRange.Cartridge"
            }
        }

        var bytesToRead: Int {
            switch self {
            case .header:
                return Int(Controller.Platform.headerRange.count)
            case .range(let range):
                return range.count
            case .cartridge(let header):
                return header.romSize
            }
        }
        
        var startingAddress: Controller.Platform.AddressSpace {
            switch self {
            case .header:
                return Controller.Platform.headerRange.lowerBound
            case .range(let range):
                return Controller.Platform.AddressSpace(range.lowerBound)
            case .cartridge:
                return 0
            }
        }
    }
}
