import ORSSerial
import Gibby

public class InsideGadgetsCartridgeController: ThreadSafeSerialPortController {
    @discardableResult
    public override final func send(_ data: Data?, timeout: UInt32? = nil) -> Bool {
        defer { usleep(250) }
        return super.send(data, timeout: timeout)
    }

    public override func open() -> ORSSerialPort {
        return super.open().configuredAsGBxCart()
    }
}

extension InsideGadgetsCartridgeController {
    public static func controller() throws -> InsideGadgetsCartridgeController {
        return try InsideGadgetsCartridgeController(matching: .prefix("/dev/cu.usbserial-14"))
    }
}

extension InsideGadgetsCartridgeController {
    public struct Version: CustomStringConvertible {
        fileprivate init(major: Int = 1, minor: Int, revision: String) {
            self.major = major
            self.minor = minor
            self.revision = revision.lowercased()
        }
        
        let major: Int
        let minor: Int
        let revision: String
        
        public var description: String {
            return "v\(major).\(minor)\(revision)"
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
