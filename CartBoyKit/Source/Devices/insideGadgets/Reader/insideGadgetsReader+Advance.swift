import Gibby

extension InsideGadgetsReader where Cartridge.Platform == GameboyAdvance, Cartridge.Header.Index == Cartridge.Platform.AddressSpace {
    public func header(result: @escaping (Result<Cartridge.Header, CartridgeReaderError<Cartridge>>) -> ()) {
        self.controller.add(BlockOperation {
            result(self.header(prepare: { _ in }).mapError { .invalidHeader($0) })
        })
    }
}
