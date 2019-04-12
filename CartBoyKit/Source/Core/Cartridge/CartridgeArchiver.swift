import Gibby

/**
 Describes an interface that sends or receives save data to and from cartridges.

 Archivers are capable of:
 
    - _backing_ up save data __from__,
    - _restoring_ save data __to__, and
    - _deleting_ save data __off of__
 
 any cartridges that support such necessary hardware.
 */
@available(macOS 10.11, *)
public protocol CartridgeArchiver {
    associatedtype Cartridge: Gibby.Cartridge
    func backup(progress callback: @escaping (Progress) -> (), result: @escaping (Result<Data, Error>) -> ())
    func restore(data: Data, progress callback: @escaping (Progress) -> (), result: @escaping (Result<(), Error>) -> ())
    func delete(progress callback: @escaping (Progress) -> (), result: @escaping (Result<(), Error>) -> ())
}
