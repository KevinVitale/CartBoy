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
        _ = expectation(description: "opened")
        
        let controller = try! GBxSerialPortController.controller(for: GameboyClassic.Cartridge.self)
        
        for _ in 0..<3 {
            controller.addOperation(SerialPacketOperation(controller: controller, delegate: controller, intent: .read(count: 0x8000, context: OperationContext.cartridge)) {
                let cart = GameboyClassic.Cartridge(bytes: $0!)
                print(cart.header)
                print(cart)
            })
        }

        waitForExpectations(timeout: 10)
    }

    /*
    func testPerformanceExample() {
        // This is an example of a performance test case.
        self.measure {
            // Put the code you want to measure the time of here.
        }
    }
     */
}
