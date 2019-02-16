import ORSSerial
import Gibby

public protocol ReaderController {
    associatedtype Platform = Gibby.Platform
    
    var reader: ORSSerialPort! { get }
    
    func openReader(matching profile: ORSSerialPortManager.PortProfile) throws
    func read<Result: PlatformMemory>(rom memoryRange: ReadROMOperation<Platform>.MemoryRange, result: @escaping ((Result?) -> ())) where Result.Platform == Platform
}

extension ReaderController {
    public func operation<Result: PlatformMemory>(for memoryRange: ReadROMOperation<Platform>.MemoryRange, result: @escaping ((Result?) -> ())) -> ReadROMOperation<Platform> where Result.Platform == Platform {
        return ReadROMOperation(device: reader, memoryRange: memoryRange, cleanup: result)
    }
}


public enum ReaderControllerError: Error {
    case failedToOpen(ORSSerialPort)
}
