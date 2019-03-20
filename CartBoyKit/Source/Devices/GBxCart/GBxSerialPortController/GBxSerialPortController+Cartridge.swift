import Gibby

extension GBxSerialPortController {
    public static func controller<Cartridge: Gibby.Cartridge>(for cartrige: Cartridge.Type) throws -> GBxCartridgeController<Cartridge> where Cartridge.Platform == GameboyClassic {
        return try GBxCartridgeControllerClassic<Cartridge>()
    }
    
    public static func controller<Cartridge: Gibby.Cartridge>(for cartrige: Cartridge.Type) throws -> GBxCartridgeController<Cartridge> where Cartridge.Platform == GameboyAdvance {
        return try GBxCartridgeControllerAdvance<Cartridge>()
    }
}
