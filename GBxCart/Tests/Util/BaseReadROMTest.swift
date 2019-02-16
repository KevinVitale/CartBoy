import XCTest
import ORSSerial
import Gibby
import GBxCartKit

open class BaseReadROMTest<Gameboy: Platform>: XCTestCase {
    private(set) var reader: ORSSerialPort!
    private let queue = OperationQueue()
    
    final func read<Result: PlatformMemory>(rom memoryRange: ReadROMOperation<Gameboy>.MemoryRange, result: @escaping ((Result?) -> ())) where Result.Platform == Gameboy {
        queue.addOperation(operation(for: memoryRange, result: result))
    }
}

extension BaseReadROMTest {
    fileprivate final func operation<Result: PlatformMemory>(for memoryRange: ReadROMOperation<Gameboy>.MemoryRange, result: @escaping ((Result?) -> ())) -> ReadROMOperation<Gameboy> where Result.Platform == Gameboy {
        return ReadROMOperation(device: reader, memoryRange: memoryRange, cleanup: result)
    }
}
