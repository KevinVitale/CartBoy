import Gibby

public protocol CartridgeReader {
    associatedtype Cartridge: Gibby.Cartridge
    func readHeader(result: @escaping (Cartridge.Header?) -> ()) -> Operation
    func readCartridge(with header: Cartridge.Header?, result: @escaping (Cartridge?) -> ()) -> Operation
}
