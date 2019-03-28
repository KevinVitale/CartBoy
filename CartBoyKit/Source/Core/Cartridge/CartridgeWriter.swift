import Gibby

public protocol CartridgeWriter {
    associatedtype FlashCartridge: CartKit.FlashCartridge
    
    func erase(result: @escaping (Bool) -> ()) -> Operation
    func write(_ flashCartridge: FlashCartridge, result: @escaping (Bool) -> ()) -> Operation
}

extension CartridgeWriter {
    public func read(contentsOf url: URL) throws -> FlashCartridge {
        return try FlashCartridge(contentsOf: url)
    }
}
