import Gibby
import ORSSerial

public typealias ProgressCallback = (Double) -> ()

public protocol CartridgeController: SerialPortController {
    associatedtype Platform: Gibby.Platform
    
    func read<Number>(byteCount: Number, startingAt address: Platform.AddressSpace, timeout: TimeInterval, prepare: (() -> ())?, progress: @escaping (Progress) -> (), responseEvaluator: @escaping ORSSerialPacketEvaluator) -> Result<Data, Error> where Number: FixedWidthInteger
    
    func scanHeader(_ result: @escaping (Result<Platform.Header, Error>) -> ())
    func readCartridge(progress: @escaping ProgressCallback, _ result: @escaping (Result<Platform.Cartridge, Error>) -> ())
    

public enum CartridgeControllerError: Error {
    case platformNotSupported
}

