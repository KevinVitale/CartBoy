import XCTest
import ORSSerial
import Gibby
import GBxCartKit

final class TestReaderController<Gameboy: Platform>: NSObject, ReaderController {
    public private(set) var reader: ORSSerialPort!
    private let queue = OperationQueue()
    
    typealias Header = Gameboy.Cartridge.Header

    public final func openReader(matching profile: ORSSerialPortManager.PortProfile) throws {
        guard reader == nil else {
            return
        }
        
        self.reader = try ORSSerialPortManager.port(matching: profile)
        self.reader.open()
        guard self.reader.isOpen else {
            throw ReaderControllerError.failedToOpen(self.reader)
        }

        switch profile {
        case .GBxCart:
            self.reader = self.reader.configuredAsGBxCart()
        default: ()
        }
    }

    public final func read<Result: PlatformMemory>(rom memoryRange: ReadROMOperation<Gameboy>.MemoryRange, result: @escaping ((Result?) -> ())) where Result.Platform == Gameboy {
        self.queue.addOperation(operation(for: memoryRange, result: result))
    }
}
