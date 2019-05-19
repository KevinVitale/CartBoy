import Gibby
import ORSSerial

public typealias ProgressCallback = (Double) -> ()

public protocol CartridgeController: SerialPortController {
    static func perform(on queue: DispatchQueue, _ block: @escaping (Result<Self, Error>) -> ())
    
    func header<Platform: Gibby.Platform>(for platform: Platform.Type) -> Result<Platform.Header, Error>
    func cartridge<Platform: Gibby.Platform>(for platform: Platform.Type, progress: @escaping (Double) -> ()) -> Result<Platform.Cartridge, Error>
    
    func backupSave<Platform: Gibby.Platform>(for platform: Platform.Type, progress: @escaping (Double) -> ()) -> Result<Data, Error>
    func restoreSave<Platform: Gibby.Platform>(for platform: Platform.Type, data: Data, progress: @escaping (Double) -> ()) -> Result<(), Error>
    func deleteSave<Platform: Gibby.Platform>(for platform: Platform.Type, progress: @escaping (Double) -> ()) -> Result<(), Error>
    
    func write<FlashCartridge: CartKit.FlashCartridge>(to flashCartridge: FlashCartridge, progress: @escaping (Double) -> ()) -> Result<(), Error>
    func erase<FlashCartridge: CartKit.FlashCartridge>(chipset: FlashCartridge.Type) -> Result<(), Error>
}

public enum CartridgeControllerError<Platform: Gibby.Platform>: Error {
    case platformNotSupported(Platform.Type)
    case invalidHeader
}

public enum CartridgeFlashError<FlashCartridge: CartKit.FlashCartridge>: Error {
    case unsupportedChipset(FlashCartridge.Type)
}

