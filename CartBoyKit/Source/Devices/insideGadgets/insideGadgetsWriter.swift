import Gibby

public struct InsideGadgetsWriter<FlashCartridge: CartKit.FlashCartridge>: CartridgeWriter {
    public init() {
    }
    
    public static func erase<Controller>(using controller: Controller, result: @escaping (Bool) -> ())  -> Operation where Controller: SerialPortController {
        fatalError("Controller does not support platform: \(FlashCartridge.Platform.self)")
    }
    
    public func write<Controller>(flashCartridge: FlashCartridge, using controller: Controller, result: @escaping (Bool) -> ()) -> Operation where Controller : SerialPortController {
        fatalError("Controller does not support platform: \(FlashCartridge.Platform.self)")
    }
}
