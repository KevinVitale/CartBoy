import Gibby

public struct AM29F016B: FlashCartridge {
    public init(contentsOf url: URL) throws {
        self = .init(bytes: try Data(contentsOf: url))
    }
    
    public init(bytes data: Data) {
        self.cartridge = Platform.Cartridge(bytes: data)
    }
    
    public typealias Platform = GameboyClassic
    public typealias Header   = Platform.Cartridge.Header
    public typealias Index    = Platform.Cartridge.Index
    
    private let cartridge: Platform.Cartridge
    
    public subscript(position: Index) -> Data.Element {
        return cartridge[Index(position)]
    }
    
    public var startIndex: Index {
        return Index(cartridge.startIndex)
    }
    
    public var endIndex: Index {
        return Index(cartridge.endIndex)
    }
    
    public func index(after i: Index) -> Index {
        return Index(cartridge.index(after: Int(i)))
    }
    
    public var fileExtension: String {
        return cartridge.fileExtension
    }
    
    public func write(to url: URL, options: Data.WritingOptions = []) throws {
        try self.cartridge.write(to: url, options: options)
    }
}

extension AM29F016B {
    public var voltage: Voltage {
        return .high
    }
    
    public static func prepare<Controller>(controller: Controller, complete: (() -> ())? = nil) throws where AM29F016B == Controller.Cartridge, Controller: ThreadSafeSerialPortController, Controller : CartridgeController {
        typealias Operation = SerialPacketOperation<Controller, Controller.Context>
        try controller.whileOpened(
            Operation.Intent.read(count: 6, context: Controller.Context.whileOpened)
            , perform: { progress in
                guard progress.completedUnitCount > 0 else {
                    controller.send("G".bytes())
                    controller.send("P".bytes())
                    controller.send("W".bytes())
                    
                    controller.send("E".bytes())
                    controller.send("", number: 0x555)
                    controller.send("", number: 0xAA)
                    controller.send("", number: 0x2AA)
                    controller.send("", number: 0x55)
                    controller.send("", number: 0x555)
                    controller.send("", number: 0xA0)
                    return
                }
        }) { _ in
            controller.send("0\0".bytes())
            complete?()
        }
    }
    
    private static func erase<Controller>(controller: Controller) throws where AM29F016B == Controller.Cartridge, Controller: ThreadSafeSerialPortController, Controller : CartridgeController {
        typealias Operation = SerialPacketOperation<Controller, Controller.Context>
        try controller.whileOpened(
            Operation.Intent.read(count: 6, context: Controller.Context.whileOpened)
            , perform: { progress in
                guard progress.completedUnitCount > 0 else {
                    controller.send("F555\0AA\0".bytes())
                    controller.send("F2AA\055\0".bytes())
                    controller.send("F555\080\0".bytes())
                    controller.send("F555\0AA\0".bytes())
                    controller.send("F2AA\055\0".bytes())
                    controller.send("F555\010\0".bytes())
                    return
                }
        }) { _ in
            controller.send("0\0".bytes())
        }
    }

    public static func erase<Controller>(controller: Controller, result: @escaping (Bool) -> ()) throws where AM29F016B == Controller.Cartridge, Controller: ThreadSafeSerialPortController, Controller : CartridgeController {
        typealias Operation = SerialPacketOperation<Controller, Controller.Context>
        
        try AM29F016B.prepare(controller: controller)
        try AM29F016B.erase(controller: controller)

        print("Erasing \(AM29F016B.self)")
        var buffer = Data()
        var sectorCount = 0
        try controller.whileOpened(Operation.Intent.read(count: 1, context: Controller.Context.whileOpened)
            , perform: { progress in
                guard progress.completedUnitCount > 0 else {
                    controller.send("A0\0".bytes())
                    controller.send("R".bytes())
                    return
                }
        } , appendData: { data in
            buffer += data
            // Don't stop reading until we receive '0xFF' as the first byte.
            guard buffer.starts(with: [0xFF]) else {
                // Wait for 'buffer' to fill with 64 bytes
                guard buffer.count % 64 == 0 else {
                    return false
                }
                // Reset 'buffer' and update metrics (sector count)
                buffer.removeAll()
                sectorCount += 1
                
                // Continue to read the next 64 bytes...
                controller.send("1".bytes())
                
                // Returning 'false' means we haven't received 0xFF as a byte
                return false
            }
            return true
        }
        ) { _ in
            print("\(AM29F016B.self) erased \(sectorCount) sectors")
            result(true)
        }
    }
}
