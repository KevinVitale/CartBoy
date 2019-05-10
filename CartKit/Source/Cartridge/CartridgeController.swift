import Gibby
import ORSSerial

public typealias ProgressCallback = (Double) -> ()

public protocol CartridgeController: SerialPortController, CartridgeReader, CartridgeWriter, CartridgeEraser {
}

public protocol CartridgeReader {
    associatedtype Platform: Gibby.Platform
    
    func read<Number>(byteCount: Number, startingAt address: Platform.AddressSpace, timeout: TimeInterval, prepare: (() -> ())?, progress: @escaping (Progress) -> (), responseEvaluator: @escaping ORSSerialPacketEvaluator) -> Result<Data, Error> where Number: FixedWidthInteger
    func sendAndWait(_ block: @escaping () -> (), responseEvaluator: @escaping ORSSerialPacketEvaluator) -> Result<Data, Error>

    func scanHeader(_ result: @escaping (Result<Platform.Header, Error>) -> ())
    func readCartridge(progress: @escaping ProgressCallback, _ result: @escaping (Result<Platform.Cartridge, Error>) -> ())
    
    func backupSave(progress: @escaping ProgressCallback, _ result: @escaping (Result<Data, Error>) -> ())
    func restoreSave(data: Data, progress: @escaping ProgressCallback, _ result: @escaping (Result<(), Error>) -> ())
    func deleteSave(progress: @escaping ProgressCallback, _ result: @escaping (Result<(), Error>) -> ())
}

public protocol CartridgeWriter {
    func write<FlashCartridge: CartKit.FlashCartridge>(_ flashCartridge: FlashCartridge, progress: @escaping ProgressCallback, _ result: @escaping (Result<(), Error>) -> ())
}

public protocol CartridgeEraser {
    func erase<FlashCartridge: CartKit.FlashCartridge>(_ chipset: FlashCartridge.Type, _ result: @escaping (Result<(), Error>) -> ())
}

public enum CartridgeControllerError<Platform: Gibby.Platform>: Error {
    case platformNotSupported(Platform.Type)
    case invalidHeader
}

public enum CartridgeFlashError<FlashCartridge: CartKit.FlashCartridge>: Error {
    case unsupportedChipset(FlashCartridge.Type)
}

