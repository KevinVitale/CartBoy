import XCTest
@testable import GBxCartKit
import Gibby
import ORSSerial

class ReadROMOperationTests: XCTestCase {
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
        
        let expectation = XCTestExpectation(description: "")
        let readROM = ReadROMOperation(device: cart, memoryRange: .header(.original)) {
            expectation.fulfill()
        }
        
        self.queue.addOperation(readROM)
        
        guard case .completed = XCTWaiter.wait(for: [expectation], timeout: 5) else {
            return XCTFail()
        }
        
        if let header = ROMHeader(gameBoy: .original, bytes: readROM.bytes) {
            print("Entry Point:\(header.bootInstructions.map { String($0, radix: 16, uppercase: true) }.joined())")
            print("Logo Check:\t\(header.isLogoValid ? "Valid" : "Invalid")")
            print("Title:\t\t\(header.title)")
            print("Manu.:\t\t\(header.manufacturer ?? "")")
            print("CBC:\t\t\(header.isColorOnly ?? false)")
            print("Licensee:\t\(header.licensee)")
            print("SGB:\t\t\(header.supportsSuperGameBoy ?? false)")
            print("MBC Type:\t\(header.config)")
            print("ROM Size:\t\(header.romSize)")
            print("ROM Size ID:\(header.romSizeID)")
            print("RAM Size:\t\(header.ramSize)")
            print("RAM Size ID:\(header.ramSizeID)")
            print("Region:\t\t\(header.region)")
            print("Old Code:\t\(header.legacyLicensee ?? 0)")
            print("Version:\t\(header.version)")
            print("H.Checksum:\t\(header.headerChecksum)")
            print("C.Checksum:\t\(header.cartChecksum)")
        }
        else {
            XCTFail("Could not construct ROM header")
        }

        XCTAssertEqual(readROM.bytes[0x4..<0x34], GameBoy.original.logo)
    }
    
    func testOperation() {
        guard let cart = self.cart, cart.isOpen else {
            return XCTFail("Serial port missing or is not open.")
        }
        //----------------------------------------------------------------------
        let expectation = XCTestExpectation(description: "")
        let readROM = ReadROMOperation(device: cart, memoryRange: .range(0x0000..<0x8000)) {
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
        
        print(readROM.bytes)
        try? readROM.bytes.write(to: URL(fileURLWithPath: "/Users/kevin/Desktop/cart.gb"))
    }
}
