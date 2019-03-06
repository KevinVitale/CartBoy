import Foundation
import ORSSerial
import Gibby

final class ReadHeaderOperation<Controller: ReaderController>: BaseReadOperation<Controller> {
    required init(controller: Controller, result: ((Header?) -> ())? = nil) {
        let startAddress = Int(Controller.Platform.headerRange.lowerBound)
        let endAddress   = Int(Controller.Platform.headerRange.upperBound)
        super.init(controller: controller, bytesToRead: startAddress..<endAddress) { data in
            result?(data.isEmpty ? nil : Header(bytes: data))
        }
    }
    
    typealias Header = Controller.Platform.Cartridge.Header

    override func main() {
        super.main()
        DispatchQueue.main.sync {
            self.controller.startReading(range: self.bytesToRead)
        }
    }
}

final class ReadCartridgeOperation<Controller: ReaderController>: BaseReadOperation<Controller> {
    required init(controller: Controller, header: Cartridge.Header, result: ((Cartridge?) -> ())? = nil) {
        self.header = header
        super.init(controller: controller, bytesToRead: 0..<header.romSize) { data in
            result?(data.isEmpty ? nil : Cartridge(bytes: data))
        }
    }
    
    typealias Cartridge = Controller.Platform.Cartridge
    
    let header: Cartridge.Header

    override func main() {
        super.main()
        let group = DispatchGroup()
        for bank in 1..<self.header.romBanks {
            group.enter()
            self.controller.stopReading()
            let operation = ReadBankOperation(controller: controller, header: header, bank: bank) { data in
                if let data = data {
                    self.bytesRead.append(data)
                }
                group.leave()
            }
            operation.start()
            group.wait()
            
            if operation.isCancelled {
                self.cancel()
            }
        }
    }
}

fileprivate final class ReadBankOperation<Controller: ReaderController>: BaseReadOperation<Controller> {
    required init(controller: Controller, header: Cartridge.Header, bank: Int = 1, result: ((Data?) -> ())? = nil) {
        self.header = header
        self.bank   = bank
        let startAddress = bank > 1 ? 0x4000 : 0x0000
        let endAddress   = 0x8000
        super.init(controller: controller, bytesToRead: startAddress..<endAddress) { data in
            result?(data.isEmpty ? nil : data)
        }
    }
    
    typealias Cartridge = Controller.Platform.Cartridge

    let header: Cartridge.Header
    private let bank: Int
    
    override func main() {
        super.main()
        DispatchQueue.main.sync {
            self.controller.set(bank: bank, with: header)
            self.controller.startReading(range: bytesToRead)
        }
    }
}
