import XCTest
import ORSSerial
import Gibby
import GBxCartKit

open class BaseReadROMTest<Gameboy: Platform>: XCTestCase {
    private(set) var reader: ORSSerialPort!
    
    func operation<Result: PlatformMemory>(for memoryRange: ReadROMOperation<Gameboy>.MemoryRange, result: @escaping ((Result?) -> ())) -> ReadROMOperation<Gameboy> where Result.Platform == Gameboy {
        return ReadROMOperation(device: reader, memoryRange: memoryRange, cleanup: result)
    }
}
