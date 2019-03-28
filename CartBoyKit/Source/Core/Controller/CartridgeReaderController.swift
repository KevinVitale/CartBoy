public protocol CartridgeReaderController: CartridgeController {
    associatedtype Reader: CartridgeReader where Reader.Cartridge == Self.Cartridge
    
    static func reader() throws -> Reader
}
