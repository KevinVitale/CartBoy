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
        exp.expectedFulfillmentCount = 1
        
        let controller = try! GBxSerialPortController.controller(for: GameboyClassic.Cartridge.self)
        controller.detect {
            print($0!)
            exp.fulfill()
        }
        
        waitForExpectations(timeout: 5)
    }

    func testExample() {
        let exp = expectation(description: "opened")
        exp.expectedFulfillmentCount = 2
        
        let controller = try! GBxSerialPortController.controller(for: GameboyClassic.Cartridge.self)
        
        
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
        let controller = try! GBxSerialPortController.controller(for: GameboyClassic.Cartridge.self)
        
        controller.detect {
            print($0!)
            exp.fulfill()
            controller.header {
                print($0!)
                exp.fulfill()
            }
        }

        waitForExpectations(timeout: 5)
    }

    func testPerformanceExample() {
        self.measure {
            let exp = expectation(description: "did read")
            let controller = try! GBxSerialPortController.controller(for: GameboyClassic.Cartridge.self)
            controller.header { _ in
                exp.fulfill()
            }
            waitForExpectations(timeout: 10)
        }
    }
    
    func testReadSaveFilePerformance() {
        self.measure {
            let exp = expectation(description: "did read")
            let controller = try! GBxSerialPortController.controller(for: GameboyClassic.Cartridge.self)
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
