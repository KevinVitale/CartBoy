import Gibby

public protocol CartridgeEraser {
    func erase<FlashCartridge: CartKit.FlashCartridge>(_ chipset: FlashCartridge.Type, _ result: @escaping (Result<(), Error>) -> ())
}

public enum CartridgeEraserError<FlashCartridge: CartKit.FlashCartridge>: Error {
    case unsupportedChipset(FlashCartridge.Type)
}

public protocol CartridgeWriter {
    associatedtype FlashCartridge: CartKit.FlashCartridge

    func erase(progress callback: @escaping (Progress) -> (), result: @escaping (Result<(), Error>) -> ())
    func write(_ flashCartridge: FlashCartridge, progress callback: @escaping (Progress) -> (), result: @escaping (Result<(), Error>) -> ())
}

public enum CartridgeWriterError {
    case invalidThreadState
}

extension CartridgeWriter {
    public func read(contentsOf url: URL) throws -> FlashCartridge {
        return try FlashCartridge(contentsOf: url)
    }
    public func read(contentsOf url: URL) -> Result<(Self, FlashCartridge), Error> {
        return Result { (self, try read(contentsOf: url)) }
    }
}
