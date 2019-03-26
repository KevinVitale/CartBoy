import Gibby

public protocol CartridgeWriter {
    associatedtype FlashCartridge: CartKit.FlashCartridge
    static func erase<Controller: SerialPortController>(using controller: Controller, result: @escaping (Bool) -> ()) -> Operation
    func write<Controller: SerialPortController>(flashCartridge: FlashCartridge, using controller: Controller, result: @escaping (Bool) -> ()) -> Operation
}

extension CartridgeWriter {
    public func read(contentsOf url: URL) throws -> FlashCartridge {
        return try FlashCartridge(contentsOf: url)
    }
}
