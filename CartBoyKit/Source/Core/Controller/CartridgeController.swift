import ORSSerial
import Gibby

/**
 A controller which manages the serial port interations as it relates to Gameboy
 readers and writesr.
 
 - note: `Cartridge` headers are required for all operations.
 - note: ROM files are _"read"_ & _"written"_, or _"erased"_ (the latter two, if they are a `FlashCart`).
 - note: Save files are _"backed-up"_, _"restored"_, or _"deleted"_, if the `Cartridge` has **SRAM** support.
 */
public protocol CartridgeController: SerialPortController {
    /// The associated platform that the adopter relates to.
    associatedtype Cartridge: Gibby.Cartridge

    /**
     */
    func header(result: @escaping ((Self.Cartridge.Header?) -> ()))
    
    /**
     */
    func read(header: Self.Cartridge.Header?, result: @escaping ((Self.Cartridge?) -> ()))
    
    /**
     */
    func backup(header: Self.Cartridge.Header?, result: @escaping (Data?, Self.Cartridge.Header) -> ())
    
    /**
     */
    func restore(from backup: Data, header: Self.Cartridge.Header?, result: @escaping (Bool) -> ())
    
    /**
     */
    func delete(header: Self.Cartridge.Header?, result: @escaping (Bool) -> ())
}
