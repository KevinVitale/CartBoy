import ORSSerial
import Gibby

public class InsideGadgetsCartridgeController<Platform: Gibby.Platform>: ThreadSafeSerialPortController {
    /**
     Initializes a controller matching the the `portProfile` provided.
     
     - Parameter portProfile: A profile describing the serial device to locate.
     
     - Throws: If no serial port matching the profile is found, a
               `PortMatchingError` is thrown.
     */
    fileprivate override init(matching portProfile: ORSSerialPortManager.PortProfile) throws {
        try super.init(matching: portProfile)
    }
    
    /// Accepts operations which are expected to execute within the context of
    /// the receiver.
    private let queue: OperationQueue = .init()

    /**
     Opens the serial port.
     
     In addition to being opened, the serial port is explicitly configured as
     if it were device manufactured by insideGadgets.com before returning.

     - Returns: An open serial port.
     */
    public override func open() -> ORSSerialPort {
        return super.open().configuredAsGBxCart()
    }
    
    /**
     Queues an `operation` for execution.
     
     - Parameter operation: The operation being queued.
     
     When `operation` starts will depend on its own particular implemenation.
     For example, `OpenPortOperation` will block until it has exclusive access
     to the port/controller associated with it.
     */
    func add(_ operation: Operation) {
        self.queue.addOperation(operation)
    }
}

extension ORSSerialPortManager.PortProfile {
    public static let GBxCart: ORSSerialPortManager.PortProfile = .usb(vendorID: 6790, productID: 29987)
}

extension InsideGadgetsCartridgeController {
    public static func reader(matching portProfile: ORSSerialPortManager.PortProfile = .GBxCart) -> Result<InsideGadgetsReader<Platform.Cartridge>, Error> {
        return Result { .init(controller: try .init(matching: portProfile)) }
    }
    
    public static func writer<FlashCartridge: CartKit.FlashCartridge>(for cartridge: FlashCartridge.Type, matching portProfile: ORSSerialPortManager.PortProfile = .GBxCart) -> Result<InsideGadgetsWriter<FlashCartridge>, Error> where FlashCartridge.Platform == Platform {
        return Result { .init(controller: try .init(matching: portProfile)) }
    }
}

extension InsideGadgetsCartridgeController {
    public struct Version: CustomStringConvertible {
        public enum Error: Swift.Error {
            case invalidData
            case invalidController(Swift.Error)
        }
        
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
    
    public static func version(_ result: @escaping (Result<Version,InsideGadgetsCartridgeController<Platform>.Version.Error>) -> ()) {
        let controller = Result { try InsideGadgetsCartridgeController(matching: .GBxCart) }
        let operation = controller.map({ controller -> SerialPortRequest<InsideGadgetsCartridgeController<Platform>> in
            return SerialPortRequest(controller: controller, unitCount: 3, maxPacketLength: 1, perform: { progress in
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
            }) {
                result($0
                    .flatMapError { .failure(.invalidController($0)) }
                    .flatMap {
                        guard $0.count == 3 else {
                            return .failure(.invalidData)
                        }
                        //------------------------------------------------------
                        let major = $0[0]
                        let minor = $0[1]
                        let revision = $0[2]
                        //------------------------------------------------------
                        return .success(.init(
                            major: Int(major)
                          , minor: Int(minor)
                          , revision: String(revision, radix: 16, uppercase: false))
                        )
                })
            }
        })
        //----------------------------------------------------------------------
        switch operation {
        case .failure(let error):
            result(.failure(.invalidController(error)))
        case .success(let operation):
            operation.start()
        }
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
