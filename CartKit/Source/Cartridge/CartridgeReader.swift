import Gibby

public protocol CartridgeReader {
    associatedtype Cartridge: Gibby.Cartridge
    func header(result: @escaping (Result<Cartridge.Platform.Header,CartridgeReaderError<Cartridge>>) -> ())
    func cartridge(progress callback: @escaping (Double) -> (), result: @escaping (Result<Cartridge,CartridgeReaderError<Cartridge>>) -> ())
}

public enum CartridgeReaderError<Cartridge: Gibby.Cartridge>: Error {
    case invalidHeader(Error)
    case invalidCartridge(Error)
}
