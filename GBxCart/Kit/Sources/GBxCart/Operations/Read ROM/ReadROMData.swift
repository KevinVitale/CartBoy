import ORSSerial
import Gibby

struct ReadROMData<Platform: Gibby.Platform> {
    init(startingAddress: Platform.AddressSpace, bytesToRead: Int) {
        self.startingAddress = startingAddress
        self.bytesToRead     = bytesToRead
    }
    
    public  let startingAddress: Platform.AddressSpace
    private let bytesToRead: Int
    private var cache: Data = Data()
    private var bytes: Data = Data()

    var isCompleted: Bool {
        return bytes.count >= bytesToRead
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

    func result<Result: PlatformMemory>() -> Result? where Result.Platform == Platform {
        return Result(bytes: bytes[0..<bytesToRead])
    }
}
