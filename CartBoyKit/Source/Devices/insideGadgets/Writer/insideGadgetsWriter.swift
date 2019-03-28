import Gibby

public struct InsideGadgetsWriter<FlashCartridge: CartKit.FlashCartridge>: CartridgeWriter {
    init(controller: InsideGadgetsCartridgeController<FlashCartridge>) {
        self.controller = controller
    }
    
    let controller: InsideGadgetsCartridgeController<FlashCartridge>
    
    public func erase(result: @escaping (Bool) -> ())  -> Operation {
        fatalError("Controller does not support platform: \(FlashCartridge.Platform.self)")
    }
    
    public func write(_ flashCartridge: FlashCartridge, result: @escaping (Bool) -> ()) -> Operation {
        fatalError("Controller does not support platform: \(FlashCartridge.Platform.self)")
    }
}
