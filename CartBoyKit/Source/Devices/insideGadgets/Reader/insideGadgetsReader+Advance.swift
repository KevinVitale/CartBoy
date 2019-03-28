import Gibby

extension InsideGadgetsReader where Cartridge.Platform == GameboyAdvance {
    public func readHeader(result: @escaping (Cartridge.Header?) -> ()) -> Operation {
        return SerialPortOperation(controller: self.controller, progress: Progress(totalUnitCount: Int64(Cartridge.Platform.headerRange.count)), perform: { progress in
        }) { data in
            
        }
    }
}
