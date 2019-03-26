import Gibby

public struct InsideGadgetsReader<Cartridge: Gibby.Cartridge>: CartridgeReader, CartridgeArchiver {
    public init() {
    }
    
    public func readHeader<Controller>(using controller: Controller, result: @escaping (Cartridge.Header?) -> ()) -> Operation where Controller: SerialPortController {
        fatalError("Controller does not platform: \(Cartridge.Platform.self)")
    }
    public func readCartridge<Controller>(using controller: Controller, with header: Cartridge.Header?, result: @escaping (Cartridge?) -> ()) -> Operation where Controller : SerialPortController {
        fatalError("Controller does not platform: \(Cartridge.Platform.self)")
    }
    
    public func backupSave<Controller>(using controller: Controller, with header: Cartridge.Header?, result: @escaping (Data?) -> ()) -> Operation where Controller : SerialPortController {
        fatalError("Controller does not platform: \(Cartridge.Platform.self)")
    }
    
    public func restoreSave<Controller>(data: Data, using controller: Controller, with header: Cartridge.Header?, result: @escaping (Bool) -> ()) -> Operation where Controller : SerialPortController {
        fatalError("Controller does not platform: \(Cartridge.Platform.self)")
    }
    
    public func deleteSave<Controller>(using controller: Controller, with header: Cartridge.Header?, result: @escaping (Bool) -> ()) -> Operation where Controller : SerialPortController {
        fatalError("Controller does not platform: \(Cartridge.Platform.self)")
    }
}
