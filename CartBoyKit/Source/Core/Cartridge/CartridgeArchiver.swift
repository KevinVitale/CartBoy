import Gibby

/**
 Describes an interface that sends or receives save data to and from cartridges.

 Archivers are capable of:
 
    - _backing_ up save data __from__,
    - _restoring_ save data __to__, and
    - _deleting_ save data __off of__
 
 cartridges that support such hardware necessary to store save data.
 */
@available(macOS 10.11, *)
public protocol CartridgeArchiver {
    associatedtype Cartridge: Gibby.Cartridge
    func backupSave(with header: Cartridge.Header?, result: @escaping (Data?) -> ())
    func restoreSave(data: Data, with header: Cartridge.Header?, result: @escaping (Bool) -> ())
    func deleteSave(with header: Cartridge.Header?, result: @escaping (Bool) -> ()) 
}

/**
 Errors which can occur while performing `CartridgeArchiver` operations.
 */
@available(macOS 10.11, *)
public enum CartridgeArchiverError: Error {
}
