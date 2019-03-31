import Gibby

public final class InsideGadgetsReader<Cartridge: Gibby.Cartridge>: NSObject, CartridgeReader, CartridgeArchiver, ProgressReporting {

    init(controller: InsideGadgetsCartridgeController<Cartridge>) {
        self.controller = controller
    }
    
    public var progress: Progress = .init()
    
    let controller: InsideGadgetsCartridgeController<Cartridge>

    public func readHeader(result: @escaping (Cartridge.Header?) -> ()) {
        fatalError("Reader does not support platform: \(Cartridge.Platform.self)")
    }
    
    public func readCartridge(with header: Cartridge.Header?, result: @escaping (Cartridge?) -> ()) {
        fatalError("Reader does not support platform: \(Cartridge.Platform.self)")
    }
    
    public func backupSave(with header: Cartridge.Header?, result: @escaping (Data?) -> ()) {
        fatalError("Reader does not support platform: \(Cartridge.Platform.self)")
    }
    
    public func restoreSave(data: Data, with header: Cartridge.Header?, result: @escaping (Bool) -> ()) {
        fatalError("Reader does not support platform: \(Cartridge.Platform.self)")
    }
    
    public func deleteSave(with header: Cartridge.Header?, result: @escaping (Bool) -> ()) {
        fatalError("Reader does not support platform: \(Cartridge.Platform.self)")
    }
}

extension InsideGadgetsReader {
    public func read<Number>(_ unitCount: Number, packetLength: Int = 64, at address: Cartridge.Platform.AddressSpace, prepare: ((InsideGadgetsCartridgeController<Cartridge>) -> ())? = nil, appendData: @escaping ((Data) -> Bool) = { _ in true }, result: @escaping (Data?) -> ()) where Number : FixedWidthInteger {
        let operation = SerialPortOperation(controller: self.controller, unitCount: Int64(unitCount), packetLength: packetLength, perform: { progress in
            guard progress.completedUnitCount > 0 else {
                self.progress.addChild(progress, withPendingUnitCount: Int64(unitCount))
                self.controller.stop()
                prepare?(self.controller)
                self.controller.go(to: address)
                self.controller.read()
                return
            }
            guard progress.completedUnitCount % Int64(packetLength) == 0 else {
                return
            }
            self.controller.continue()
        }, appendData: appendData)
        { data in
            self.controller.stop()
            result(data)
            return
        }
        self.controller.add(operation)
    }
}
