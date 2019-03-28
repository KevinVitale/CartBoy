import Gibby

public struct InsideGadgetsReader<Cartridge: Gibby.Cartridge>: CartridgeReader, CartridgeArchiver {
    init(controller: InsideGadgetsCartridgeController<Cartridge>) {
        self.controller = controller
    }
    
    let controller: InsideGadgetsCartridgeController<Cartridge>

    public func readHeader(result: @escaping (Cartridge.Header?) -> ()) -> Operation {
        fatalError("Controller does not support platform: \(Cartridge.Platform.self)")
    }
    public func readCartridge(with header: Cartridge.Header?, result: @escaping (Cartridge?) -> ()) -> Operation {
        fatalError("Controller does not support platform: \(Cartridge.Platform.self)")
    }
    
    public func backupSave(with header: Cartridge.Header?, result: @escaping (Data?) -> ()) -> Operation {
        fatalError("Controller does not support platform: \(Cartridge.Platform.self)")
    }
    
    public func restoreSave(data: Data, with header: Cartridge.Header?, result: @escaping (Bool) -> ()) -> Operation {
        fatalError("Controller does not support platform: \(Cartridge.Platform.self)")
    }
    
    public func deleteSave(with header: Cartridge.Header?, result: @escaping (Bool) -> ()) -> Operation {
        fatalError("Controller does not support platform: \(Cartridge.Platform.self)")
    }
}
