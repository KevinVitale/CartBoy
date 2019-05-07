import Gibby
import ORSSerial

public typealias ProgressCallback = (Double) -> ()

public protocol CartridgeReader: SerialPortController {
    associatedtype Platform: Gibby.Platform
    
    func read<Number>(byteCount: Number, startingAt address: Platform.AddressSpace, timeout: TimeInterval, prepare: (() -> ())?, progress: @escaping (Progress) -> (), responseEvaluator: @escaping ORSSerialPacketEvaluator) -> Result<Data, Error> where Number: FixedWidthInteger
    func sendAndWait(_ block: @escaping () -> (), responseEvaluator: @escaping ORSSerialPacketEvaluator) -> Result<Data, Error>

    func scanHeader(_ result: @escaping (Result<Platform.Header, Error>) -> ())
    func readCartridge(progress: @escaping ProgressCallback, _ result: @escaping (Result<Platform.Cartridge, Error>) -> ())
    
    func backupSave(progress: @escaping ProgressCallback, _ result: @escaping (Result<Data, Error>) -> ())
    func restoreSave(data: Data, progress: @escaping ProgressCallback, _ result: @escaping (Result<(), Error>) -> ())
    func deleteSave(progress: @escaping ProgressCallback, _ result: @escaping (Result<(), Error>) -> ())
}

public enum CartridgeReaderError<Platform: Gibby.Platform>: Error {
    case platformNotSupported(Platform.Type)
    case invalidHeader
}
