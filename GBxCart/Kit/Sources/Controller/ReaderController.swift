import ORSSerial
import Gibby

public protocol ReaderController: class {
    /// The associated platform that the adopter relates to.
    associatedtype Platform: Gibby.Platform
    
    /// The cartridge reader that this adopter is controlling.
    var reader: ORSSerialPort! { get }
    var queue: OperationQueue { get }

    /**
     Locate a serial port matching `profile`, and then attempt to open it.
     
     - parameters:
        - profile: The profile to match against.
     */
    func openReader(matching profile: ORSSerialPortManager.PortProfile) throws
    
    func sendBeginReading()
    func sendContinueReading()
    func sendGo(to address: Platform.AddressSpace)
    func sendStopBreak()
    func sendSwitch(bank: Platform.AddressSpace)
    
    // var firmwareVersion: String { get }
    // var pcbVersion
    // var cartridgeMode
}

extension ReaderController {
    /**
     Reads a memory range within the rom from the `reader`.
     
     - parameters:
     - memoryRange: An enum describing what is to be read.
     - result: A callback returning the result of the read operation.
     */
    public func read<Result: PlatformMemory>(rom memoryRange: ReadROMOperation<Self>.MemoryRange, result: @escaping ((Result?) -> ())) where Result.Platform == Platform {
        self.queue.addOperation(operation(for: memoryRange, result: result))
    }
    
    /**
     A convenience method for constructing new read operations.
     
     - note:
         Adopters can
         use this method to easily create new operations and then submit them to
         an internal queue to implement the `read(for:result:)` function.

     - parameters:
         - memoryRange: An enum describing what is to be read.
         - result: A callback returning the result of the read operation.
     */
    private func operation<Result: PlatformMemory>(for memoryRange: ReadROMOperation<Self>.MemoryRange, result: @escaping ((Result?) -> ())) -> ReadROMOperation<Self> where Result.Platform == Platform {
        return ReadROMOperation(controller: self, memoryRange: memoryRange, cleanup: result)
    }
}


public enum ReaderControllerError: Error {
    case failedToOpen(ORSSerialPort)
}
