import XCTest
import ORSSerial
import Gibby
@testable import CartKit

@objc(GameboyClassicReadROMTests)
fileprivate final class GameboyClassicReadROMTests: XCTestCase {
    func testHeader() {
        let controller = try! GBxCartridgeController<GameboyClassic.Cartridge>.controller()
        let exp = expectation(description: "Everything")
        controller.header {
            defer { exp.fulfill() }
            guard let header = $0 else {
                XCTFail()
                return
            }
            print("\(header)")
        }
        waitForExpectations(timeout: 1)
    }
    
    func testCartridge() {
        let controller = try! GBxCartridgeController<GameboyClassic.Cartridge>.controller()
        let exp = expectation(description: "Test Cartridge")
        controller.header {
            print($0!)
            controller.read(header: $0!) {
                defer { exp.fulfill() }
                guard let cartridge = $0 else {
                    XCTFail()
                    return
                }
                print("Done")
                print("MD5:", Data(cartridge[0..<cartridge.endIndex]).md5.hexString(separator: "").lowercased())
                print(String(repeating: "-", count: 45), "|", separator: "")
                print(cartridge)
                print(String(repeating: "-", count: 45), "|", separator: "")
                try! cartridge.write(to: URL(fileURLWithPath: "/Users/kevin/Desktop/\(cartridge.header.title).gb"))
            }
        }
        waitForExpectations(timeout: 35)
    }
    
    func testBackup() {
        let controller = try! GBxCartridgeController<GameboyClassic.Cartridge>.controller()
        let exp = expectation(description: "Test Backup")
        controller.header {
            guard let header = $0 else {
                return
            }
            controller.backup(header: header) { data, _ in
                defer { exp.fulfill() }
                let data = data ?? Data()
                let MD5 = data.md5.hexString(separator: "").lowercased()
                print("MD5: \(MD5)")
                
                var saveFileURL = URL(fileURLWithPath: "/Users/kevin/Desktop/\(header.title).sav")
                try! data.write(to: saveFileURL)
                saveFileURL = URL(fileURLWithPath: "/Users/kevin/Desktop/\(header.title).sav.bak")
                try! data.write(to: saveFileURL)
            }
        }
        waitForExpectations(timeout: 5)
    }
    
    func testRestore() {
        let controller = try! GBxCartridgeController<GameboyClassic.Cartridge>.controller()
        let exp = expectation(description: "Test Restore")
        
        controller.header {
            guard let header = $0 else {
                return
            }
            var saveFileData: Data = .init()
            do {
                saveFileData = try Data(contentsOf: URL(fileURLWithPath: "/Users/kevin/Desktop/\(header.title).sav.bak"))
            } catch {
                XCTFail("No such save file")
                exp.fulfill()
                return
            }
            
            controller.restore(from: saveFileData, header: header) {
                defer { exp.fulfill() }
                guard $0 else {
                    XCTFail()
                    return
                }
            }
        }
        waitForExpectations(timeout: 10)
    }
    
    func testDelete() {
        let controller = try! GBxCartridgeController<GameboyClassic.Cartridge>.controller()
        let exp = expectation(description: "Test Delete")
        controller.header {
            guard let header = $0 else {
                print($0!)
                exp.fulfill()
                return
            }
            controller.delete(header: header) {
                defer { exp.fulfill() }
                guard $0 else {
                    XCTFail()
                    return
                }
            }
        }
        waitForExpectations(timeout: 10)
    }

    func testBoardInfo() {
        let controller = try! GBxCartridgeController<GameboyClassic.Cartridge>.controller()
        let exp = expectation(description: "Test Board Info")
        try! controller.boardInfo {
            defer { exp.fulfill() }
            print($0!)
        }
        
        waitForExpectations(timeout: 1)
    }

    func testPerformanceExample() {
        let controller = try! GBxCartridgeController<GameboyClassic.Cartridge>.controller()
        self.measure {
            let exp = expectation(description: "did read")
            controller.header {
                defer { exp.fulfill() }
                guard $0!.isLogoValid else {
                    XCTFail($0!.debugDescription)
                    return
                }
                // print($0!)
            }
            waitForExpectations(timeout: 10)
        }
    }
    
    func testEraseFlashCart() {
        let controller = try! GBxCartridgeController<AM29F016B>.controller()
        let exp = expectation(description: "Test Board Info")
        exp.expectedFulfillmentCount = 1
        try! AM29F016B.erase(controller: controller) {
            defer { exp.fulfill() }
            print(#function)
            XCTAssertTrue($0)
        }
        waitForExpectations(timeout: 300)
    }
    
    private typealias Operation = SerialPacketOperation<GBxCartridgeController<AM29F016B>, GBxCartridgeController<AM29F016B>.Context>
    func testWriteFlashCart() {
        let controller = try! GBxCartridgeController<AM29F016B>.controller()
        let exp = expectation(description: "Test Write Flash Cart")
        let romTitle = "POKEMON YELLOW"
        let romFileURL = URL(fileURLWithPath: "/Users/kevin/Desktop/\(romTitle).gb")
        let flashCart = try! AM29F016B(contentsOf: romFileURL)
        
        print(flashCart, "MD5:", Data(flashCart[0..<flashCart.endIndex]).md5.hexString(separator: "").lowercased())
        print(flashCart.header)

        try! AM29F016B.erase(controller: controller) {
            XCTAssertTrue($0)
            guard $0 else {
                return
            }
            controller.write(flashCart: flashCart) {
                XCTAssertTrue($0)
                controller.header {
                    defer { exp.fulfill() }
                    print($0!)
                }
            }
        }
        waitForExpectations(timeout: 300)
    }
}
