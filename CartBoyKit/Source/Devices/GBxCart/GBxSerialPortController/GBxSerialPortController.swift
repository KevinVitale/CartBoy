import ORSSerial
import Gibby

/**
 */
open class GBxSerialPortController: NSObject, SerialPortController, SerialPacketOperationDelegate {
    /**
     */
     public required init(matching portProfile: ORSSerialPortManager.PortProfile = .GBxCart) throws {
        self.reader = try ORSSerialPortManager.port(matching: portProfile)
        super.init()
    }
    
    ///
    final let reader: ORSSerialPort

    ///
    private let isOpenCondition = NSCondition()
    
    ///
    private var currentDelegate: ORSSerialPortDelegate? = nil // Prevents 'deinit'
    private var        delegate: ORSSerialPortDelegate? {
        get { return reader.delegate     }
        set {
            currentDelegate = newValue
            reader.delegate = newValue
        }
    }

    /**
     */
    public final func openReader(delegate: ORSSerialPortDelegate?) {
        self.isOpenCondition.whileLocked {
            while self.currentDelegate != nil {
                self.isOpenCondition.wait()
            }
            
            // print("Continuing...")
            self.delegate = delegate
            //------------------------------------------------------------------
            DispatchQueue.main.sync {
                if self.reader.isOpen == false {
                    self.reader.open()
                    self.reader.configuredAsGBxCart()
                }
            }
        }
    }
    
    /**
     */
    @discardableResult
    public final func send(_ data: Data?) -> Bool {
        guard let data = data else {
            return false
        }
        return self.reader.send(data)
    }
}

extension GBxSerialPortController {
    ///
    public var isOpen: Bool {
        return self.reader.isOpen
    }

    /**
     */
    @discardableResult
    public final func close() -> Bool {
        return self.reader.close()
    }
}

extension GBxSerialPortController {
    /**
     */
    @objc public func packetOperation(_ operation: Operation, didComplete intent: Any?) {
        self.isOpenCondition.whileLocked {
            self.delegate = nil
            self.isOpenCondition.signal()
        }
    }
}

extension GBxSerialPortController {
    /**
     */
    public struct Version: Equatable, Codable, CustomDebugStringConvertible {
        public let major: String
        public let minor: String
        public let revision: String
        
        public var debugDescription: String {
            return "v\(major).\(minor)\(revision)"
        }
        
        fileprivate mutating func change(major value: String) {
            self = .init(major: value, minor: minor, revision: revision)
        }
        
        fileprivate mutating func change(minor value: String) {
            self = .init(major: major, minor: value, revision: revision)
        }
        
        fileprivate mutating func change(revision value: String) {
            self = .init(major: major, minor: minor, revision: value)
        }
    }
    
    /**
     */
    public func detect(_ callback: @escaping ((Version, Voltage)?) -> ()) {
        self.whileOpened(perform: { () -> ((Version, Voltage)) in
            var version = Version(major: "1", minor: "", revision: "")
            let group = DispatchGroup()
            //------------------------------------------------------------------
            // STOP
            //------------------------------------------------------------------
            self.send("0".bytes())
            //------------------------------------------------------------------
            // PCB Version
            //------------------------------------------------------------------
            group.enter()
            self.reader.send(ORSSerialRequest(
                dataToSend: "h\0".bytes()!
                , userInfo: nil
                , timeoutInterval: 5
                , responseDescriptor: ORSSerialPacketDescriptor(maximumPacketLength: 1, userInfo: nil) {
                    version.change(minor: $0!.hexString().lowercased())
                    group.leave()
                    return true
            }))
            //------------------------------------------------------------------
            // Firmware Version
            //------------------------------------------------------------------
            group.enter()
            self.reader.send(ORSSerialRequest(
                dataToSend: "V\0".bytes()!
                , userInfo: nil
                , timeoutInterval: 5
                , responseDescriptor: ORSSerialPacketDescriptor(maximumPacketLength: 1, userInfo: nil) {
                    version.change(revision: $0!.hexString().lowercased())
                    group.leave()
                    return true
            }))
            //------------------------------------------------------------------
            // Voltage Version
            //------------------------------------------------------------------
            var voltage: Voltage = .high
            group.enter()
            self.reader.send(ORSSerialRequest(
                dataToSend: "C\0".bytes()!
                , userInfo: nil
                , timeoutInterval: 5
                , responseDescriptor: ORSSerialPacketDescriptor(maximumPacketLength: 1, userInfo: nil) {
                    voltage = ($0!.hexString() == "1") ? .high : .low
                    group.leave()
                    return true
            }))
            //------------------------------------------------------------------
            // WAIT
            //------------------------------------------------------------------
            group.wait()
            //------------------------------------------------------------------
            // CALLBACK
            //------------------------------------------------------------------
            return (version, voltage)
        }, callback)
    }
}
