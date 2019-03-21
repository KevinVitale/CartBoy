import XCTest
import ORSSerial
import Gibby
@testable import CartKit



class SerialPacketOperationTests: XCTestCase {

    override func setUp() {
        // Put setup code here. This method is called before the invocation of each test method in the class.
    }

    override func tearDown() {
        // Put teardown code here. This method is called after the invocation of each test method in the class.
    }
    
    func testDetect() {
        let exp = expectation(description: "opened")
        exp.expectedFulfillmentCount = 2
        
        
        let controller = try! GBxCartridgeController<GameboyClassic.Cartridge>.controller()
        controller.version { print($0!); exp.fulfill() }
        controller.voltage { print($0!); exp.fulfill() }

        waitForExpectations(timeout: 5)
    }

    func testExample() {
        let exp = expectation(description: "opened")
        exp.expectedFulfillmentCount = 2
        
        let controller = try! GBxCartridgeController<GameboyClassic.Cartridge>.controller()

        
        for _ in 0..<exp.expectedFulfillmentCount {
            controller.read {
                let cart = $0!
                print(cart.header)
                print(cart)
                exp.fulfill()
            }
        }

        waitForExpectations(timeout: 100)
    }
    
    func testSerialPacketBlockOperation() {
        let exp = expectation(description: "opened")
        exp.expectedFulfillmentCount = 2
        
        
        let controller = try! GBxCartridgeController<GameboyClassic.Cartridge>.controller()
        var header: GameboyClassic.Cartridge.Header? = nil {
            didSet {
                print(header!)
                exp.fulfill()
            }
        }
        controller.whileOpened(perform: {
            exp.fulfill()
            
            controller.header {
                header = $0
            }
            return nil
        }) { _ in
        }

        waitForExpectations(timeout: 5)
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
    
    func testReadSaveFilePerformance() {
        self.measure {
            let exp = expectation(description: "did read")
            let controller = try! GBxCartridgeController<GameboyClassic.Cartridge>.controller()
            controller.backup { data, header in
                if let data = data {
                    print(data.md5.hexString(separator: "").lowercased())
                }
                exp.fulfill()
            }
            waitForExpectations(timeout: 10)
        }
    }
}
