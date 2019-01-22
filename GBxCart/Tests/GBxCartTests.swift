import XCTest
import ORSSerial
import GBxCartKit
import Gibby

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
    
    func testCartWithURL() {
        var cart = try! Cartridge(contentsOf: URL(string:"file:///Users/kevin/Desktop/cart.gb")!)
        XCTAssertTrue(cart.isLogoValid)
        print("Logo Check: \(cart.isLogoValid ? "OK" : "INVALID")")
        
        let entryPoint = Data([0x00, 0xC3, 0x50])
        XCTAssertEqual(cart.entryPoint, entryPoint)
        XCTAssertEqual(cart.title, "TETRIS")

        XCTAssertTrue(cart.manufacturer.isEmpty)
        XCTAssertEqual(cart.licensee, "0")
        XCTAssertTrue(cart.legacyLicensee == .legacy(code: 1))
        XCTAssertTrue(cart.colorMode == .none)
        XCTAssertFalse(cart.superGameboySupported)
        XCTAssertTrue(cart.memoryController == .rom(ram: false, battery: false))
        XCTAssertTrue(cart.romSize == "0")
        XCTAssertTrue(cart.ramSize == "0")
        XCTAssertEqual(cart.region, "Japanese")
        XCTAssertEqual(cart.headerChecksum, "A")
        XCTAssertEqual(cart.cartChecksum, "16BF")
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
        
        let stream = GBxCartReadStream(responseEvaluator: { data in
            guard let data = data else {
                return true
            }
            return data.count >= 0x8000
        }) { result in
            switch result {
            case .stopped(let stream):
                try? stream.buffer.write(to: self.url)
                fallthrough
            default:
                self.expectation.fulfill()
            }
        }
        stream.start(port: device, address: 0x0)
        
        guard case .completed = XCTWaiter.wait(for: [self.expectation!], timeout: 180) else {
            return XCTFail()
        }

        var cart = Cartridge(system: .original)
        cart.colorMode = .none
        cart.title     = "kevins big game hunter"
        XCTAssertTrue(cart.isLogoValid)
        XCTAssertTrue(cart.title == "KEVINS BIG GAME ")
        
        // try? cart.write(to: self.url)

        let bytes = stream.buffer[0x100..<0x150]
        print(bytes.indices)
        print(Data(bytes).indices)
        cart.header = bytes

        XCTAssertTrue(cart.isLogoValid)
        print()
        print("Entry ASM: ", (cart.entryPoint).map({ data in String(data, radix: 16, uppercase: true) }).joined(separator: " "))
        print("Logo Check: \(cart.isLogoValid ? "OK" : "INVALID")")
        print("Title: ", cart.title)
        print("Manufacturer: ", cart.manufacturer)
        print("Licensee: ", cart.licensee)
        print("Legacy Licensee: ", cart.legacyLicensee)
        print("Color Mode: ", cart.colorMode)
        print("SGB Support: ", cart.superGameboySupported)
        print("MBC: ", cart.memoryController)
        print("ROM Size: ", cart.romSize)
        print("RAM Size: ", cart.ramSize)
        print("Region: ", cart.region)
        print("Version: ", cart.version)
        print("Header Checksum: ", cart.headerChecksum)
        print("Cart Checksum: ", cart.cartChecksum)
        print()
        
        /*
        self.expectation = XCTestExpectation(description: "again")
        device.open()
        XCTAssertTrue(device.isOpen)
        headerData = Data(count: 80)
        stream = GBxCartReadStream(responseEvaluator: { data in
            guard let data = data else {
                return true
            }
            return data.count >= 0x80
        }) { result in
            switch result {
            case .stopped(let stream):
                headerData = stream.buffer[headerData.indices]
                try? stream.buffer.write(to: self.url)
                fallthrough
            default:
                self.expectation.fulfill()
            }
        }
        stream.start(port: device, address: 0x100)
        
        guard case .completed = XCTWaiter.wait(for: [self.expectation!], timeout: 180) else {
            return XCTFail()
        }
        
        XCTAssert(headerData.count == 80)
        header = Header(bytes: headerData)
        print()
        print("Entry ASM: ", header.entryPoint.map({ data in String(data, radix: 16, uppercase: true) }).joined(separator: " "))
        print("Logo Check: \(headerData[.logo] == GameBoy.original.logo ? "OK" : "INVALID")")
        print("Title: ", header.title)
        print("Manufacturer: ", header.manufacturer)
        print("Licensee: ", header.licensee)
        print("Legacy Licensee: ", header.legacyLicensee)
        print("Color Mode: ", header.colorMode)
        print("SGB Support: ", header.superGameboySupported)
        print("MBC: ", header.memoryController)
        print("ROM Size: ", header.romSize)
        print("RAM Size: ", header.ramSize)
        print("Region: ", header.region)
        print("Version: ", header.version)
        print("Header Checksum: ", header.headerChecksum)
        print("Cart Checksum: ", header.cartChecksum)
        print()
         */

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
