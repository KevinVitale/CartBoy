import Gibby

public protocol CartridgeArchiver {
    associatedtype Cartridge: Gibby.Cartridge
    func backupSave<Controller: SerialPortController>(using controller: Controller, with header: Cartridge.Header?, result: @escaping (Data?) -> ()) -> Operation
    func restoreSave<Controller: SerialPortController>(data: Data, using controller: Controller, with header: Cartridge.Header?, result: @escaping (Bool) -> ()) -> Operation
    func deleteSave<Controller: SerialPortController>(using controller: Controller, with header: Cartridge.Header?, result: @escaping (Bool) -> ()) -> Operation
}
