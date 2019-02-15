import ORSSerial
import Gibby

struct ReadROMData<Gameboy: Platform> {
    init(operation: ReadROMOperation<Gameboy>, memoryRange: ReadROMOperation<Gameboy>.MemoryRange) {
        self.operation = operation
        self.memoryRange = memoryRange
    }
    
    private var bytes: Data = Data()
    private let memoryRange: ReadROMOperation<Gameboy>.MemoryRange
    
    private weak var operation: ReadROMOperation<Gameboy>!
    private var cache: Data = Data()
    
    var startingAddress: Int {
        return memoryRange.startingAddress
    }
    
    var isCompleted: Bool {
        return bytes.count >= memoryRange.bytesToRead
    }
    
    private var isCacheFilled: Bool {
        return (64 - cache.count) <= 0
    }
    
    mutating func erase() {
        self.bytes = Data()
    }
    
    mutating func append(next data: Data, stop: inout Bool) {
        self.cache.append(data)
        if self.isCacheFilled {
            self.bytes.append(self.cache)
            self.cache = Data()
        }
        
        stop = self.isCompleted
    }

    func result<Result: PlatformMemory>() -> Result? where Result.Platform == Gameboy {
        guard self.bytes.indices.overlaps(memoryRange.indices) else {
            return nil
        }
        return Result(bytes: bytes[memoryRange.indices])
    }
}
