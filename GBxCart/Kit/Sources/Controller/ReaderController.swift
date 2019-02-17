import ORSSerial
import Gibby

public protocol ReaderController {
    /// The associated platform that the adopter relates to.
    associatedtype Platform = Gibby.Platform
    
    /// The cartridge reader that this adopter is controlling.
    var reader: ORSSerialPort! { get }

    /**
     Locate a serial port matching `profile`, and then attempt to open it.
     
     - parameters:
        - profile: The profile to match against.
     */
    func openReader(matching profile: ORSSerialPortManager.PortProfile) throws
    
    /**
     Reads a memory range within the rom from the `reader`.
     
     - parameters:
     - memoryRange: An enum describing what is to be read.
     - result: A callback returning the result of the read operation.
     */
    func read<Result: PlatformMemory>(rom memoryRange: ReadROMOperation<Platform>.MemoryRange, result: @escaping ((Result?) -> ())) where Result.Platform == Platform
}

extension ReaderController {
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
    public func operation<Result: PlatformMemory>(for memoryRange: ReadROMOperation<Platform>.MemoryRange, result: @escaping ((Result?) -> ())) -> ReadROMOperation<Platform> where Result.Platform == Platform {
        return ReadROMOperation(device: reader, memoryRange: memoryRange, cleanup: result)
    }
}


public enum ReaderControllerError: Error {
    case failedToOpen(ORSSerialPort)
}
