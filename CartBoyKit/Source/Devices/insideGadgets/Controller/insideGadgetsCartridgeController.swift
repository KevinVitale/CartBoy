import ORSSerial
import Gibby

public class InsideGadgetsCartridgeController<Platform: Gibby.Platform>: ThreadSafeSerialPortController, CartridgeController {
    fileprivate override init(matching portProfile: ORSSerialPortManager.PortProfile = .prefix("/dev/cu.usbserial-14")) throws {
        try super.init(matching: portProfile)
    }
    
    private let queue: OperationQueue = .init()

    @discardableResult
    override final func send(_ data: Data?, timeout: UInt32? = nil) -> Bool {
        return super.send(data, timeout: timeout)
    }

    public override func open() -> ORSSerialPort {
        return super.open().configuredAsGBxCart()
    }
    
    func add(_ operation: Operation) {
        self.queue.addOperation(operation)
    }
}

extension InsideGadgetsCartridgeController {
    public static func reader<Cartridge: Gibby.Cartridge>(for cartridge: Cartridge.Type) throws -> InsideGadgetsReader<Cartridge> where Cartridge.Platform == Platform {
        return .init(controller: try .init())
    }
    
    public static func writer<FlashCartridge: CartKit.FlashCartridge>(for cartridge: FlashCartridge.Type) throws -> InsideGadgetsWriter<FlashCartridge> where FlashCartridge.Platform == Platform {
        return .init(controller: try .init())
    }
}

extension InsideGadgetsCartridgeController {
    public struct Version: CustomStringConvertible {
        init(major: Int = 1, minor: Int, revision: String) {
            self.major = major
            self.minor = minor
            self.revision = revision.lowercased()
        }
        
        private let major: Int
        private let minor: Int
        private let revision: String
        
        public var description: String {
            return "v\(major).\(minor)\(revision)"
        }
    }
    
    public static func version(result: @escaping (Version?) -> ()) throws {
        let controller = try InsideGadgetsCartridgeController()
        controller.add(SerialPortOperation(controller: controller, unitCount: 3, packetLength: 1, perform: { progress in
            guard progress.completedUnitCount > 0 else {
                controller.send("C\0".bytes())
                return
            }
            guard progress.completedUnitCount > 1 else {
                controller.send("h\0".bytes())
                return
            }
            guard progress.completedUnitCount > 2 else {
                controller.send("V\0".bytes())
                return
            }
        }) { data in
            guard let major = data?[0], let minor = data?[1], let revision = data?[2] else {
                result(nil)
                return
            }
            result(.init(major: Int(major), minor: Int(minor), revision: String(revision, radix: 16, uppercase: false)))
        })
    }
}

extension InsideGadgetsCartridgeController {
    @discardableResult
    func go(to address: Platform.AddressSpace, timeout: UInt32 = 250) -> Bool {
        return send("A", number: address, timeout: timeout)
    }
    
    @discardableResult
    func read() -> Bool {
        switch Platform.self {
        case is GameboyClassic.Type:
            return send("R".bytes())
        case is GameboyAdvance.Type:
            return send("r".bytes())
        default:
            return false
        }
    }

    @discardableResult
    func stop(timeout: UInt32 = 0) -> Bool {
        return send("0".bytes(), timeout: timeout)
    }
    
    @discardableResult
    func `continue`() -> Bool {
        return send("1".bytes())
    }
}

extension ORSSerialPort {
    @discardableResult
    fileprivate final func configuredAsGBxCart() -> ORSSerialPort {
        self.allowsNonStandardBaudRates = true
        self.baudRate = 1000000
        self.dtr = true
        self.rts = true
        self.numberOfDataBits = 8
        self.numberOfStopBits = 1
        self.parity = .none
        return self
    }
}
