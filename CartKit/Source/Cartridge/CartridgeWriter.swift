import Gibby

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
