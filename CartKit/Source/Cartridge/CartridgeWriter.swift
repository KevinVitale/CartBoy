import Gibby

public protocol CartridgeWriter {
    func write<FlashCartridge: CartKit.FlashCartridge>(_ flashCartridge: FlashCartridge, progress: @escaping ProgressCallback, _ result: @escaping (Result<(), Error>) -> ())
}

public protocol CartridgeEraser: CartridgeWriter {
    func erase<FlashCartridge: CartKit.FlashCartridge>(_ chipset: FlashCartridge.Type, _ result: @escaping (Result<(), Error>) -> ())
}

public enum CartridgeFlashError<FlashCartridge: CartKit.FlashCartridge>: Error {
    case unsupportedChipset(FlashCartridge.Type)
}
