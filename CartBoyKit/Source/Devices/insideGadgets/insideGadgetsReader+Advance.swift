import Gibby

extension InsideGadgetsReader where Cartridge.Platform == GameboyAdvance {
    public func readHeader<Controller>(using controller: Controller, result: @escaping (Cartridge.Header?) -> ()) -> Operation where Controller: SerialPortController {
        return SerialPortOperation(controller: controller, progress: Progress(totalUnitCount: Int64(Cartridge.Platform.headerRange.count)), perform: { progress in
        }) { data in
            
        }
    }
}
