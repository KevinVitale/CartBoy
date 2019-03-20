import ORSSerial
import Gibby

final class GBxCartridgeControllerAdvance<Cartridge: Gibby.Cartridge>: GBxCartridgeController<Cartridge> where Cartridge.Platform == GameboyAdvance {
}
