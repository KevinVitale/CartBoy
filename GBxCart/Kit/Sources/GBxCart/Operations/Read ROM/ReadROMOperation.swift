import Foundation
import ORSSerial
import Gibby

public final class ReadHeaderOperation<Controller: ReaderController>: BaseReadOperation<Controller> {
    public required init(controller: Controller, result: ((Header?) -> ())? = nil) {
        super.init(controller: controller, numberOfBytesToRead: Controller.Platform.headerRange.count) { data in
            result?(data.isEmpty ? nil : Header(bytes: data))
        }
    }
    
    public typealias Header = Controller.Platform.Cartridge.Header

    public override func main() {
        super.main()
        self.controller.sendStopBreak()
        self.controller.sendGo(to: Controller.Platform.headerRange.lowerBound)
        self.controller.sendBeginReading()
    }
}

public final class ReadCartridgeOperation<Controller: ReaderController>: BaseReadOperation<Controller> {
    public required init(controller: Controller, header: Cartridge.Header, result: ((Cartridge?) -> ())? = nil) {
        self.header = header
        super.init(controller: controller, numberOfBytesToRead: header.romSize) { data in
            result?(data.isEmpty ? nil : Cartridge(bytes: data))
        }
    }
    
    private let header: Cartridge.Header
    
    public typealias Cartridge = Controller.Platform.Cartridge

    public override func main() {
        super.main()
        self.controller.sendStopBreak()
        self.controller.sendGo(to: 0)
        self.controller.sendBeginReading()
    }
}

