import Gibby

public protocol CartridgeArchiver {
    associatedtype Cartridge: Gibby.Cartridge
    func backupSave(with header: Cartridge.Header?, result: @escaping (Data?) -> ())
    func restoreSave(data: Data, with header: Cartridge.Header?, result: @escaping (Bool) -> ())
    func deleteSave(with header: Cartridge.Header?, result: @escaping (Bool) -> ()) 
}
