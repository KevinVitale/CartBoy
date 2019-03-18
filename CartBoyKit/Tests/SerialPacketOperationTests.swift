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

    func testExample() {
        let exp = expectation(description: "opened")
        exp.expectedFulfillmentCount = 10
        
        let controller = try! GBxSerialPortController.controller(for: GameboyClassic.Cartridge.self)
        
        for _ in 0..<exp.expectedFulfillmentCount {
            controller.addOperation(SerialPacketOperation(controller: controller, delegate: controller, intent: .read(count: 0x8000, context: GBxSerialPortController.OperationContext.cartridge)) {
                let cart = GameboyClassic.Cartridge(bytes: $0!)
                print(cart.header)
                print(cart)
                exp.fulfill()
            })
        }

        waitForExpectations(timeout: 100)
    }

    func testPerformanceExample() {
        self.measure {
            let exp = expectation(description: "did read")
            let controller = try! GBxSerialPortController.controller(for: GameboyClassic.Cartridge.self)
            controller.addOperation(SerialPacketOperation(controller: controller, delegate: controller, intent: .read(count: 80, context: GBxSerialPortController.OperationContext.header)) { _ in
                // print(GameboyClassic.Cartridge.Header(bytes: $0!))
                exp.fulfill()
            })
            waitForExpectations(timeout: 10)
        }
    }
}
