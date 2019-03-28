import Gibby

public protocol CartridgeArchiver {
    associatedtype Cartridge: Gibby.Cartridge
    func backupSave(with header: Cartridge.Header?, result: @escaping (Data?) -> ()) -> Operation
    func restoreSave(data: Data, with header: Cartridge.Header?, result: @escaping (Bool) -> ()) -> Operation
    func deleteSave(with header: Cartridge.Header?, result: @escaping (Bool) -> ()) -> Operation
}
