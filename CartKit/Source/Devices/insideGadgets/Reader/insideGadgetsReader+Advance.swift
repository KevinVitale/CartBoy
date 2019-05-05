import Gibby

extension InsideGadgetsReader where Cartridge.Platform == GameboyAdvance {
    public func header(result: @escaping (Result<Cartridge.Platform.Header, CartridgeReaderError<Cartridge>>) -> ()) {
        self.controller.add(BlockOperation {
            result(self.header(prepare: { _ in }).mapError { .invalidHeader($0) })
        })
    }
}
