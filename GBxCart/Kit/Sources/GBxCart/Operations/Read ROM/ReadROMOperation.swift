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
        self.controller.sendHaltReading()
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
    
    public typealias Cartridge = Controller.Platform.Cartridge
    private typealias Platform = Controller.Platform
    private typealias AddressSpace = Platform.AddressSpace
    
    fileprivate let header: Cartridge.Header
    fileprivate let readCondition = NSCondition()
    fileprivate var bankByteCount: (total: Int, remaining: Int) = (0, 0)
    private var readROMStrategy: ReadROMStrategy<Platform> = Platform.self is GameboyClassic.Type ? .classic : .advance

    public override func main() {
        super.main()
        
        self.readCondition.whileLocked {
            self.readROMStrategy.execute(self)
        }
    }

    public override func serialPort(_ serialPort: ORSSerialPort, didReceive data: Data) {
        super.serialPort(serialPort, didReceive: data)
        
        self.bankByteCount.remaining -= data.count
        if self.bankByteCount.remaining == 0 {
            self.controller.sendHaltReading()
            self.readCondition.signal()
        }
    }
}

fileprivate enum ReadROMStrategy<Platform: Gibby.Platform> {
    case classic
    case advance
    
    func execute<Controller: ReaderController>(_ operation: ReadCartridgeOperation<Controller>) where Controller.Platform == Platform {
        operation.controller.sendHaltReading()
        
        for currentBank in 1..<Platform.AddressSpace(operation.header.romBanks) {
            print("Bank: \(currentBank)")
            
            let bankByteCount = currentBank > 1 ? 0x4000 : 0x8000
            let address       = Platform.AddressSpace(currentBank > 1 ? 0x4000 : 0x0000)
            operation.bankByteCount = (bankByteCount, bankByteCount)

            if case .one = (operation.header as! GameboyClassic.Cartridge.Header).configuration {
                operation.controller.sendSwitch(bank: 0, at: 0x6000)
                operation.controller.sendSwitch(bank: currentBank >> 5, at: 0x4000)
                operation.controller.sendSwitch(bank: currentBank & 0x1F, at: 0x2000)
            }
            else {
                operation.controller.sendSwitch(bank: currentBank, at: 0x2100)
                if currentBank >= 0x100 {
                    operation.controller.sendSwitch(bank: 1, at: 0x3000)
                }
            }
            
            operation.controller.sendGo(to: address)
            operation.controller.sendBeginReading()
            
            operation.readCondition.wait()
            operation.controller.sendHaltReading()
            let prefix = operation.bytesRead.suffix(from: operation.bytesRead.count - 0x4000).map { String($0, radix: 16, uppercase: true)}.joined(separator: " ")
            print(#function, operation.bytesRead, prefix.prefix(0x40))
        }
    }
}
