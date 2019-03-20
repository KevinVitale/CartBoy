import ORSSerial

/**
 */
public protocol SerialPortController: class, NSObjectProtocol {
    ///
    var isOpen: Bool { get }
    
    ///
    var version: SerialPortControllerVendorVersion { get }
    
    /**
     */
    func addOperation<Operation: SerialPacketOperation<Self>>(_ operation: Operation)
    
    /**
     */
    func openReader(delegate: ORSSerialPortDelegate?)
    
    /**
     */
    @discardableResult
    func close() -> Bool

    /**
     */
    @discardableResult
    func send(_ data: Data) -> Bool
}

/**
 */
public struct SerialPortControllerVendorVersion: Equatable, Codable, CustomDebugStringConvertible {
    public let major: String
    public let minor: String
    public let revision: String
    
    public var debugDescription: String {
        return "v\(major).\(minor)\(revision)"
    }
    
    mutating func change(major value: String) {
        self = .init(major: value, minor: minor, revision: revision)
    }
    
    mutating func change(minor value: String) {
        self = .init(major: major, minor: value, revision: revision)
    }

    mutating func change(revision value: String) {
        self = .init(major: major, minor: minor, revision: value)
    }
}
