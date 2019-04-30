import Gibby

/**
 Writes and/or reads **save** data to and from cartridges.

 Cartridge archivers are capable of:
 
    - _backing_ up save data __from__,
    - _restoring_ save data __to__, and
    - _deleting_ save data __off of__
 
 any cartridges that support such necessary hardware.
 */
public protocol CartridgeArchiver {
    associatedtype Cartridge: Gibby.Cartridge
    func backup(progress callback: @escaping (Double) -> (), result: @escaping (Result<Data, Error>) -> ())
    func restore(data: Data, progress callback: @escaping (Double) -> (), result: @escaping (Result<(), Error>) -> ())
    func delete(progress callback: @escaping (Double) -> (), result: @escaping (Result<(), Error>) -> ())
}
