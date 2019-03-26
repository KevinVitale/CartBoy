import Gibby

public protocol CartridgeReader {
    associatedtype Cartridge: Gibby.Cartridge
    func readHeader<Controller: SerialPortController>(using controller: Controller, result: @escaping (Cartridge.Header?) -> ()) -> Operation
    func readCartridge<Controller: SerialPortController>(using controller: Controller, with header: Cartridge.Header?, result: @escaping (Cartridge?) -> ()) -> Operation
}
