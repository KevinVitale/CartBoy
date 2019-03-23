import XCTest
import ORSSerial
import Gibby
import CartKit

@objc(GameboyClassicReadROMTests)
fileprivate final class GameboyClassicReadROMTests: XCTestCase {
    func testController() {
        let exp = expectation(description: "Everything")
        exp.expectedFulfillmentCount = 4
        
        let controller = try! GBxCartridgeController<GameboyClassic.Cartridge>.controller()
        
        controller.header {
            defer { exp.fulfill() }
            guard let header = $0 else {
                XCTFail()
                return
            }
            print("\(header)")
            controller.read(header: header) {
                guard let cartridge = $0 else {
                    XCTFail()
                    return
                }
                print("Done")
                print("MD5:", Data(cartridge[0..<cartridge.endIndex]).md5.hexString(separator: "").lowercased())
                print(String(repeating: "-", count: 45), "|", separator: "")
                print(cartridge)
                print(String(repeating: "-", count: 45), "|", separator: "")
                exp.fulfill()
            }
            controller.backup(header: header) { data, _ in
                guard let data = data else {
                    XCTFail()
                    return
                }
                print("Backup Finished")
                print(data)
                exp.fulfill()
            }
            
            controller.boardInfo { print($0!); exp.fulfill() }
        }
        waitForExpectations(timeout: 16)
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
                print($0!)
            }
            waitForExpectations(timeout: 10)
        }
    }
}
