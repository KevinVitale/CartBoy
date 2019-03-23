import XCTest
import ORSSerial
import Gibby
import CartKit

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
            controller.read {
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
            }
        }
        waitForExpectations(timeout: 16)
    }
    
    /*
    func testBackup() {
        let controller = try! GBxCartridgeController<GameboyClassic.Cartridge>.controller()
        let exp = expectation(description: "Test Backup")
        controller.header {
            guard let header = $0 else {
                return
            }
            controller.backup(header: header) { data, _ in
                defer { exp.fulfill() }
                if !header.configuration.hardware.contains(.ram) {
                    print("WARNING: Cartridge does not support SRAM")
                }
                else {
                    let MD5 = (data ?? Data()).md5.hexString(separator: "").lowercased()
                    print("MD5: \(MD5)")
                }
            }
        }
        waitForExpectations(timeout: 1)
    }
     */
    
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
}
