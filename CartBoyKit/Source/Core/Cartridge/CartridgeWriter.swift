import Gibby

public protocol CartridgeWriter {
    associatedtype FlashCartridge: CartKit.FlashCartridge
    static func erase<Controller: SerialPortController>(using controller: Controller, result: @escaping (Bool) -> ()) -> Operation
}
