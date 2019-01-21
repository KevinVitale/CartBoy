import XCTest
import ORSSerial
import GBxCartKit
import Gibby

public struct Header {
}

extension Header {
    public enum Section: RawRepresentable {
        public enum HeaderAddress: RawRepresentable, ExpressibleByIntegerLiteral {
            case zero
            case cart
            case address(at: Int)
            
            public var rawValue: Int {
                switch self {
                case .zero: return 0x00
                case .cart: return 0x150
                case .address(let address): return address
                }
            }
            
            public init(rawValue: Int) {
                switch rawValue {
                case 0x00: self = .zero
                case 0x150: self = .cart
                default: self = .address(at: rawValue)
                }
            }
            
            public init(integerLiteral value: Int) {
                self.init(rawValue: value)
            }
        }
        indirect case beginningAt(HeaderAddress, Section)
        
        case boot
        case logo
        case title
        case manufacturer
        case colorFlag
        case licensee
        case superGameboyFlag
        case memoryController
        case romSize
        case ramSize
        case destination
        case legacyLicensee
        case versionMask
        case headerChecksum
        case cartChecksum
        case invalid(Range<Int>)

        private func lowerBound(at address: HeaderAddress = .cart) -> Int {
            switch self {
            case .beginningAt(let address, let section): return section.lowerBound(at: address)
            case .boot:             return 0x00.advanced(by: address.rawValue)
            case .logo:             return 0x04.advanced(by: address.rawValue)
            case .title:            return 0x34.advanced(by: address.rawValue)
            case .manufacturer:     return 0x3F.advanced(by: address.rawValue)
            case .colorFlag:        return 0x04.advanced(by: address.rawValue)
            case .licensee:         return 0x34.advanced(by: address.rawValue)
            case .superGameboyFlag: return 0x46.advanced(by: address.rawValue)
            case .memoryController: return 0x47.advanced(by: address.rawValue)
            case .romSize:          return 0x48.advanced(by: address.rawValue)
            case .ramSize:          return 0x49.advanced(by: address.rawValue)
            case .destination:      return 0x4A.advanced(by: address.rawValue)
            case .legacyLicensee:   return 0x4B.advanced(by: address.rawValue)
            case .versionMask:      return 0x4C.advanced(by: address.rawValue)
            case .headerChecksum:   return 0x4D.advanced(by: address.rawValue)
            case .cartChecksum:     return 0x4E.advanced(by: address.rawValue)
            case .invalid(let range): return range.lowerBound.advanced(by: address.rawValue)
            }
        }
        
        public var size: Int {
            switch self {
            case .beginningAt(_, let section): return section.size
            case .boot:             return 3
            case .logo:             return 48
            case .title:            return 16
            case .manufacturer:     return 4
            case .colorFlag:        return 1
            case .licensee:         return 2
            case .superGameboyFlag: return 1
            case .memoryController: return 1
            case .romSize:          return 1
            case .ramSize:          return 1
            case .destination:      return 2
            case .legacyLicensee:   return 1
            case .versionMask:      return 1
            case .headerChecksum:   return 1
            case .cartChecksum:     return 2
            case .invalid(let range): return range.count
            }
        }
        
        public var rawValue: Range<Int> {
            return lowerBound()..<lowerBound().advanced(by: size)
        }
        
        public init(rawValue: Range<Int>) {
            self = Section.allSections.filter({ $0.rawValue == rawValue }).first ?? .invalid(rawValue)
        }
        
        public init(rawValue: Range<Int>, headerAddress address: HeaderAddress) {
            guard address != .cart else {
                self = Section(rawValue: (rawValue.lowerBound.advanced(by: HeaderAddress.cart.rawValue)..<rawValue.upperBound.advanced(by: HeaderAddress.cart.rawValue)))
                return
            }
            self = Section.allSections
                .map    ({ .beginningAt(address, $0) })
                .filter ({ $0.rawValue == rawValue })
                .first  ?? .beginningAt(address, .invalid(rawValue))
        }

        public static var allSections: [Section] {
            return [
                  .boot
                , .logo
                , .title
                , .manufacturer
                , .colorFlag
                , .licensee
                , .superGameboyFlag
                , .memoryController
                , .romSize
                , .ramSize
                , .destination
                , .legacyLicensee
                , .versionMask
                , .headerChecksum
                , .cartChecksum
            ]
        }
    }
}

extension Data {
    subscript(section: Header.Section) -> Data? {
        guard self.indices.overlaps(section.rawValue) else {
            return nil
        }
        return self[section.rawValue]
    }
}

class GBxCartReadStream: NSObject, ORSSerialPortDelegate {
    enum Result {
        case closed(port: ORSSerialPort)
        case removed(port: ORSSerialPort)
        case stopped(GBxCartReadStream)
    }
    
    private(set) var buffer = Data()
    private let response: ORSSerialPacketEvaluator
    private let callback: ((Result) -> ())?
    private private(set) var previousDelegate: ORSSerialPortDelegate? = nil

    init(responseEvaluator response: @escaping ORSSerialPacketEvaluator, result callback: ((Result) -> ())? = nil) {
        self.response = response
        self.callback = callback
        super.init()
    }

    func serialPortWasRemovedFromSystem(_ serialPort: ORSSerialPort) {
        self.callback?(.removed(port: serialPort))
        serialPort.delegate = self.previousDelegate
    }
    
    func serialPortWasClosed(_ serialPort: ORSSerialPort) {
        self.callback?(.closed(port: serialPort))
        serialPort.delegate = self.previousDelegate
    }
    
    func serialPort(_ serialPort: ORSSerialPort, didReceive data: Data) {
        self.buffer.append(data)
        guard !self.response(self.buffer) else {
            serialPort.send(.stop)
            self.callback?(.stopped(self))
            serialPort.delegate = self.previousDelegate
            serialPort.close()
            return
        }
        if (self.buffer.count % 64) == 0 {
            serialPort.send(.continue)
        }
    }
    
    func start(port: ORSSerialPort, address: Int) {
        self.previousDelegate = port.delegate
        port.delegate = self
        port.send(.stop, .goto(address: address), .read)
    }
}

class GBxCartTests: XCTestCase {
    private(set) var expectation: XCTestExpectation! = nil
    var device: ORSSerialPort! = nil
    var url: URL! = nil
    var bytesRead: Data = .init()
    var bytesToRead: UInt = 0
    var readHeader = false

    override func setUp() {
        expectation = .init(description: "\(self.testRunClass!)")
        bytesRead = .init()
    }
    
    override func tearDown() {
        self.device = nil
    }

    func testDeviceInitWithPath() {
        guard let device = ORSSerialPortManager.GBxCart() else {
            ORSSerialPortManager.shared().availablePorts.forEach {
                print($0.path)
            }
            return XCTFail("Could not find 'GBxCart' device. Make sure it's connected.")
        }
        defer {
            XCTAssertTrue(device.close())
        }
        
        guard let url = NSSearchPathForDirectoriesInDomains(.desktopDirectory, .userDomainMask, true)
            .map({ URL(fileURLWithPath: $0) }).first else {
                return XCTFail()
        }
        
        self.url = url.appendingPathComponent("cart.gb")
        self.device = device
        device.delegate = self
        device.open()
        XCTAssertTrue(device.isOpen)
        
        let d = Data(repeating: 0xFF, count: 0x150)
        Header.Section.allSections.forEach {
            XCTAssert(d[$0]?.count == $0.size)
        }

        let section = Header.Section(rawValue: (0x00..<0x03), headerAddress: .cart)
        print(d[.beginningAt(.zero, .logo)])

        let stream = GBxCartReadStream(responseEvaluator: { data in
            guard let data = data else {
                return true
            }
            return data.count >= 0x8000
        }) { result in
            switch result {
            case .stopped(let stream):
                // print(stream.buffer.map({ String($0, radix: 16, uppercase: true)}).joined(separator: " "))
                try? stream.buffer.write(to: self.url)
                fallthrough
            default:
                self.expectation.fulfill()
            }
        }
        stream.start(port: device, address: 0x0)

        /*
        var bytesRead = Data()
        let maxPacketLength = min (bytesToRead, 64)
        let desc = ORSSerialPacketDescriptor(maximumPacketLength: maxPacketLength, userInfo: nil) { data in
            guard let data = data else {
                return true
            }
            bytesRead.append(data)
            return data.count == maxPacketLength
        }
        let req = ORSSerialRequest(instruction: .read, userInfo: userInfo, timeoutInterval: 180, responseDescriptor: desc)
        device.send(req)
         */


        /*
        self.readHeader = true
        XCTAssertTrue(device.send("0".data(using: .ascii)!))
        XCTAssertTrue(device.send("A100\0".data(using: .ascii)!))
        self.bytesToRead = UInt(0x80)
        self.bytesRead = .init()
        XCTAssertTrue(device.send("R".data(using: .ascii)!))
         */

        /*
        self.readHeader = false
        XCTAssertTrue(device.send("0".data(using: .ascii)!))
        XCTAssertTrue(device.send("A0\0".data(using: .ascii)!))
        self.bytesToRead = UInt(0x8000)
        self.bytesRead = .init()
        XCTAssertTrue(device.send("R".data(using: .ascii)!))
         */

        /*
        XCTAssertTrue(device.send("1".data(using: .ascii)!))
        XCTAssertTrue(device.send("1".data(using: .ascii)!))
        XCTAssertTrue(device.send("1".data(using: .ascii)!))
         */
        
        // device.send(.stop, .goto(address: 0x100), .read(bytes: 0xFF), .stop)
       // device.send(.stop, .goto(address: 0x0), .read(bytes: 48), .stop)
        
        // device.send(.firmwareVersion, .cartMode, .pcbVersion)

        /*
        let logoPacketDescriptor = ORSSerialPacketDescriptor(packetData: GameBoy.original.logo, userInfo: nil)
        let pageBoundryPacketDescriptor = ORSSerialPacketDescriptor(maximumPacketLength: 64, userInfo: nil) { data in
            guard let data = data else {
                return false
            }
            return data.count >= 64
        }
         */

        /*
        let req = ORSSerialRequest(dataToSend: "R".data(using: .ascii)!
            , userInfo: nil
            , timeoutInterval: 30
            , responseDescriptor: pageBoundryPacketDescriptor
        )
         */

        /*
        XCTAssertTrue(device.send("0".data(using: .ascii)!))
        XCTAssertTrue(device.send("A104\0".data(using: .ascii)!))
        XCTAssertTrue(device.send(req))
         */
        
        
        /*
        XCTAssertTrue(device.send("0".data(using: .ascii)!))
        XCTAssertTrue(device.send("A0\0".data(using: .ascii)!))
        device.startListeningForPackets(matching: pageBoundryPacketDescriptor)
        XCTAssertTrue(device.send("R".data(using: .ascii)!))
         */

        
        
        /*
        XCTAssertTrue(device.send("0".data(using: .ascii)!))
        XCTAssertTrue(device.send("V\0".data(using: .ascii)!))
        XCTAssertTrue(device.send("C\0".data(using: .ascii)!))
        XCTAssertTrue(device.send("h\0".data(using: .ascii)!))
        XCTAssertTrue(device.send("0".data(using: .ascii)!))
        XCTAssertTrue(device.send("A\0".data(using: .ascii)!))
        XCTAssertTrue(device.send("R".data(using: .ascii)!))
         */

        guard case .completed = XCTWaiter.wait(for: [self.expectation!], timeout: 180) else {
            return XCTFail()
        }
    }
}

extension GBxCartTests: ORSSerialPortDelegate {
    func serialPortWasRemovedFromSystem(_ serialPort: ORSSerialPort) {
        print(#function)
    }
    
    func serialPort(_ serialPort: ORSSerialPort, requestDidTimeout request: ORSSerialRequest) {
        print(#function)
    }
    
    func serialPort(_ serialPort: ORSSerialPort, didEncounterError error: Error) {
        print(#function)
    }
    
    func serialPortWasClosed(_ serialPort: ORSSerialPort) {
        print(#function)
    }
    
    func serialPortWasOpened(_ serialPort: ORSSerialPort) {
        print(#function)
    }
    
    func serialPort(_ serialPort: ORSSerialPort, didReceive data: Data) {
        // print(data.map({ String($0, radix: 16, uppercase: true)}).joined(separator: " "))
        /*
        self.bytesRead.append(data)

        guard self.bytesRead.count < self.bytesToRead else {
            defer {
                self.bytesRead = .init()
                self.bytesToRead = 0
                serialPort.send("0".data(using: .ascii)!)
            }
            if (self.readHeader) {
                print(
                    String(data: bytesRead[0x034..<0x03F].filter { $0 != 0x00 }, encoding: .ascii)!
                    , String(data: bytesRead[0x034..<0x044].filter { $0 != 0x00 }, encoding: .ascii)!
                    , String(bytesRead[0x043], radix: 16, uppercase: true)
                    , MemoryController.init(rawValue: bytesRead[0x047])!
                    , String(bytesRead[0x046], radix: 16, uppercase: true)
                    , String(bytesRead[0x048], radix: 16, uppercase: true)
                    , String(bytesRead[0x049], radix: 16, uppercase: true)
                    , String(bytesRead[0x04A], radix: 16, uppercase: true)
                )
                return
            }

            try? self.bytesRead.write(to: self.url)
            self.expectation.fulfill()
            return
        }
        
        if (self.bytesRead.count % 64 == 0) {
            serialPort.send("1".data(using: .ascii)!)
        }
         */
    }

    func serialPort(_ serialPort: ORSSerialPort, didReceivePacket packetData: Data, matching descriptor: ORSSerialPacketDescriptor) {
    }

    func serialPort(_ serialPort: ORSSerialPort, didReceiveResponse responseData: Data, to request: ORSSerialRequest) {
        print(#function)
        serialPort.send(.stop)
        print(responseData.map({ String($0, radix: 16, uppercase: true)}).joined(separator: " "))
        /*
        print(responseData)
         */
    }
}

extension ORSSerialPort {
    func send(_ instructions: GBxCart.Instruction...) {
        instructions.forEach { self.send($0.data) }
    }
}
extension ORSSerialRequest {
    convenience init(instruction: GBxCart.Instruction, userInfo: Any?, timeoutInterval: TimeInterval, responseDescriptor: ORSSerialPacketDescriptor?) {
        self.init(dataToSend: instruction.data, userInfo: userInfo, timeoutInterval: timeoutInterval, responseDescriptor: responseDescriptor)
    }
}
