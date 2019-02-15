import XCTest
@testable import GBxCartKit
import Gibby
import ORSSerial

class ReadROMOperationTests: XCTestCase {
    fileprivate typealias GameboyClassicROM = ReadROMOperation<GameboyClassic>
    
    private var cart: ORSSerialPort?
    private let queue = OperationQueue()

    override func setUp() {
        defer {
            if self.cart?.isOpen == false {
                self.cart?.open()
            }
            /* Un-comment is this ever becomes important.
            else {
                self.addTeardownBlock {
                    self.cart?.close()
                }
            }
             */
        }
        guard self.cart != nil else {
            do {
                self.cart = try ORSSerialPortManager.GBxCart()
            } catch {
                print(error)
            }
            return
        }
    }

    func testHeaderOperation() {
        guard let cart = self.cart, cart.isOpen else {
            return XCTFail("Serial port missing or is not open.")
        }
        //----------------------------------------------------------------------
        
        var header: GameboyClassicROM.Cartridge.Header!
        let expectation = XCTestExpectation(description: "")
        let readROM = GameboyClassicROM(device: cart, memoryRange: .header) { (result: GameboyClassicROM.Cartridge.Header?) in
            header = result
            expectation.fulfill()
        }
        
        self.queue.addOperation(readROM)
        
        guard case .completed = XCTWaiter.wait(for: [expectation], timeout: 5)
            , header != nil else {
                return XCTFail("\n.: Header is 'nil' :.")
        }

        print("Entry Point:\(header.bootInstructions.map { String($0, radix: 16, uppercase: true) }.joined())")
        print("Logo Check:\t\(header.isLogoValid ? "Valid" : "Invalid")")
        print("Title:\t\t\(header.title)")
        print("Manu.:\t\t\(header.manufacturer)")
        print("CBC:\t\t\(header.colorMode)")
        print("Licensee:\t\(header.licensee)")
        print("SGB:\t\t\(header.superGameboySupported)")
        print("MBC Type:\t\(header.configuration)")
        print("ROM Size:\t\(header.romSize)")
        print("ROM Size ID:\(header.romSizeID)")
        print("RAM Size:\t\(header.ramSize)")
        print("RAM Size ID:\(header.ramSizeID)")
        print("Region:\t\t\(header.region)")
        print("Old Code:\t\(header.legacyLicensee)")
        print("Version:\t\(header.version)")
        print("H.Checksum:\t\(header.headerChecksum)")
        print("C.Checksum:\t\(header.romChecksum)")

        XCTAssertTrue(header.isLogoValid)
    }
    
    func testOperation() {
        guard let cart = self.cart, cart.isOpen else {
            return XCTFail("Serial port missing or is not open.")
        }
        //----------------------------------------------------------------------
        
        var rom: GameboyClassicROM.Cartridge = .init(bytes: Data())
        
        let expectation = XCTestExpectation(description: "")
        let readROM = GameboyClassicROM(device: cart, memoryRange: .range(0x0000..<0x8000)) { (result: GameboyClassicROM.Cartridge?) in
            if let result = result {
                rom = result
            }
            expectation.fulfill()
        }
        
        self.queue.addOperation(readROM)
        
        /* Test Cancel */
        /*
        DispatchQueue.main.asyncAfter(deadline: .now()) {
            readROM.cancel()
        }
         */

        guard case .completed = XCTWaiter.wait(for: [expectation], timeout: 5) else {
            return XCTFail()
        }
        
        print(rom)
        // try? readROM.bytes.write(to: URL(fileURLWithPath: "/Users/kevin/Desktop/cart.gb"))
    }
}
