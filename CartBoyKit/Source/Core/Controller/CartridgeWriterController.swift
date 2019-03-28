public protocol CartridgeWriterController: CartridgeController {
    associatedtype Writer: CartridgeWriter where Writer.FlashCartridge == Self.Cartridge
    
    static func writer() throws -> Writer
}
