import ORSSerial

public final class GBxCart: NSObject {
}

extension GBxCart {
    public enum Instruction: RawRepresentable, Codable, ExpressibleByStringLiteral {
        case stop
        case `continue`
        case read
        case goto(address: Int)
        case firmwareVersion
        case pcbVersion
        case cartMode
        case none
        
        public var rawValue: String {
            switch self {
            case .stop:                 return "0"
            case .continue:             return "1"
            case .read:                 return "R"
            case .goto(let address):    return "A\(String(address, radix: 16, uppercase: true))\0"
            case .firmwareVersion:      return "V\0"
            case .pcbVersion:           return "h\0"
            case .cartMode:             return "C\0"
            case .none:                 return ""
            }
        }
        
        public var data: Data {
            return rawValue.data(using: .ascii)!
        }
        
        public init(rawValue: String) {
            switch rawValue.first {
            case "0"?: self = .stop
            case "1"?: self = .continue
            case "R"?: self = .read
            case "A"?:
                if let address = Int(rawValue.dropFirst().dropLast()) {
                    self = .goto(address: address)
                } else {
                    self = .none
                }
            case "V"?: self = .firmwareVersion
            case "h"?: self = .pcbVersion
            case "C"?: self = .cartMode
            default: self = .none
            }
        }
        
        public init(stringLiteral value: String) {
            self.init(rawValue: value)
        }
    }
}


public class GBxCartReadRequest: NSObject {
    private static let pageSize: UInt = 64
    private static let sendData = "R".data(using: .ascii)!
    
    private let pageCount:  UInt
    private var pagesRead:  UInt = 0
    private var hexAddress: String
    
    private var requests = [ORSSerialRequest]()
    private weak var port: ORSSerialPort?

    public required init(startingAddress address: Int, count bytesToRead: UInt, timeoutInterval: TimeInterval = 180, from port: ORSSerialPort) {
        self.pageCount  = bytesToRead / GBxCartReadRequest.pageSize
        self.hexAddress = String(address, radix: 16, uppercase: true)
        super.init()
        
        self.port = port
        
        /*
        let maximumPacketLength = { min(bytesToRead, GBxCartReadRequest.pageSize) }
        let desc = ORSSerialPacketDescriptor(
            maximumPacketLength: maximumPacketLength()
          , userInfo: ["Request":self]) { data in
            guard let data = data else {
                return false
            }
            return data.count == maximumPacketLength()
        }
         */

        self.requests = [
            .init(dataToSend: GBxCartReadRequest.sendData
                , userInfo: nil
                , timeoutInterval: timeoutInterval
                , responseDescriptor: nil
            )]
    }
}
