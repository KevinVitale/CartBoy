import Gibby

public struct InsideGadgetsWriter<FlashCartridge: CartKit.FlashCartridge>: CartridgeWriter {
    public static func erase<Controller>(using controller: Controller, result: @escaping (Bool) -> ())  -> Operation where Controller: SerialPortController {
        fatalError("Controller does not support platform: \(FlashCartridge.Platform.self)")
    }
}
