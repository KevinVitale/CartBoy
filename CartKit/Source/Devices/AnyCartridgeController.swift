import Foundation
import ORSSerial
import Gibby

public final class AnyCartridgeController<Controller: CartridgeController>: CartridgeController {
    private init(_ controller: Controller) {
        self.controller = controller
    }
    
    private let controller: Controller
    
    public static func perform(on queue: DispatchQueue = DispatchQueue(label: ""), _ block: @escaping (Result<AnyCartridgeController<Controller>, Error>) -> ()) {
        Controller.perform(on: queue) { controller in
            block(controller.map { AnyCartridgeController($0) })
        }
    }
    
    public func header<Platform: Gibby.Platform>(for platform: Platform.Type) -> Result<Platform.Header, Error> {
        return self.controller.header(for: platform)
    }
    
    public func cartridge<Platform: Gibby.Platform>(for platform: Platform.Type, progress: @escaping (Double) -> ()) -> Result<Platform.Cartridge, Error> {
        return self.controller.cartridge(for: platform, progress: progress)
    }
    
    public func backupSave<Platform: Gibby.Platform>(for platform: Platform.Type, progress: @escaping (Double) -> ()) -> Result<Data, Error> {
        return self.controller.backupSave(for: platform, progress: progress)
    }
    
    public func restoreSave<Platform: Gibby.Platform>(for platform: Platform.Type, data: Data, progress: @escaping (Double) -> ()) -> Result<(), Error> {
        return self.controller.restoreSave(for: platform, data: data, progress: progress)
    }
    
    public func deleteSave<Platform: Gibby.Platform>(for platform: Platform.Type, progress: @escaping (Double) -> ()) -> Result<(), Error> {
        return self.controller.deleteSave(for: platform, progress: progress)
    }
    
    public func write<FlashCartridge: CartKit.FlashCartridge>(to flashCartridge: FlashCartridge, progress: @escaping (Double) -> ()) -> Result<(), Error> {
        return self.controller.write(to: flashCartridge, progress: progress)
    }
    
    public func erase<FlashCartridge: CartKit.FlashCartridge>(chipset: FlashCartridge.Type) -> Result<(), Error> {
        return self.controller.erase(chipset: chipset)
    }
    
    public var isOpen: Bool {
        return self.controller.isOpen
    }
    
    public func openReader(delegate: ORSSerialPortDelegate?) {
        self.controller.openReader(delegate: delegate)
    }
    
    public func closePort() -> Bool {
        return self.controller.closePort()
    }
    
    public func close(delegate: ORSSerialPortDelegate) {
        self.controller.close(delegate: delegate)
    }
}

