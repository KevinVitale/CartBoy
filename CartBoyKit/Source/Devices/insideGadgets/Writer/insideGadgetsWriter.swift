import Gibby

public final class InsideGadgetsWriter<FlashCartridge: CartKit.FlashCartridge>: NSObject, CartridgeWriter, ProgressReporting {
    init(controller: InsideGadgetsCartridgeController<FlashCartridge>) {
        self.controller = controller
    }
    
    public var progress: Progress = .init()

    let controller: InsideGadgetsCartridgeController<FlashCartridge>
    
    public func erase(result: @escaping (Bool) -> ()) {
        fatalError("Controller does not support platform: \(FlashCartridge.Platform.self)")
    }
    
    public func write(_ flashCartridge: FlashCartridge, result: @escaping (Bool) -> ()) {
        fatalError("Controller does not support platform: \(FlashCartridge.Platform.self)")
    }
}

extension InsideGadgetsWriter {
    public func read<Number>(_ unitCount: Number, packetLength: Int = 64, at address: FlashCartridge.Platform.AddressSpace, prepare: ((InsideGadgetsCartridgeController<FlashCartridge>) -> ())? = nil, appendData: @escaping ((Data) -> Bool) = { _ in true }, result: @escaping (Data?) -> ()) where Number : FixedWidthInteger {
        let operation = SerialPortOperation(controller: self.controller, unitCount: Int64(unitCount), packetLength: packetLength, perform: { progress in
            guard progress.completedUnitCount > 0 else {
                self.progress.addChild(progress, withPendingUnitCount: Int64(unitCount))
                self.controller.stop()
                self.controller.break()
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
    
    public func write(_ data: Slice<FlashCartridge>, packetLength: Int = 1, at address: FlashCartridge.Platform.AddressSpace, prepare: ((InsideGadgetsCartridgeController<FlashCartridge>) -> ())? = nil, appendData: @escaping ((Data) -> Bool) = { _ in true }, result: @escaping () -> ()) {
        let unitCount = Int64(data.count / 64)
        let operation = SerialPortOperation(controller: self.controller, unitCount: unitCount, packetLength: packetLength, perform: { progress in
            if progress.completedUnitCount == 0 {
                self.progress.addChild(progress, withPendingUnitCount: unitCount)
                self.controller.stop()
                prepare?(self.controller)
            }
            let startAddress = FlashCartridge.Index(progress.completedUnitCount * 64).advanced(by: Int(data.startIndex))
            let bytesInRange  = startAddress..<FlashCartridge.Index(startAddress + 64)
            self.controller.send("T".data(using: .ascii)! + Data(data[bytesInRange]), timeout: 250)
        }, appendData: appendData)
        { _ in
            self.controller.stop(timeout: 250)
            result()
            return
        }
        self.controller.add(operation)
    }
}
