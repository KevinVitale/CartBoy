import XCTest
import ORSSerial
import Gibby
import GBxCartKit

open class BaseReadROMTest<Gameboy: Platform>: XCTestCase, ReaderController {
    public private(set) var reader: ORSSerialPort!
    private let queue = OperationQueue()
    
    public final func openReader(matching profile: ORSSerialPortManager.PortProfile) throws {
        guard reader.isOpen == false else {
            return
        }
        self.reader = try ORSSerialPortManager.port(matching: profile)
        
        switch profile {
        case .GBxCart:
            self.reader = self.reader.configuredAsGBxCart()
        default: ()
        }
    }

    public final func read<Result: PlatformMemory>(rom memoryRange: ReadROMOperation<Gameboy>.MemoryRange, result: @escaping ((Result?) -> ())) where Result.Platform == Gameboy {
        queue.addOperation(operation(for: memoryRange, result: result))
    }
}
