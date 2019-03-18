import XCTest
import ORSSerial
import Gibby
@testable import CartKit

fileprivate enum OperationContext {
    case header
    case cartridge
    case saveFile
}

extension GBxSerialPortController: SerialPacketOperationDelegate {

    public func packetOperation(_ operation: Operation, didBeginWith intent: Any?) {
        guard let intent = intent as? PacketIntent, case .read(_, let context?) = intent, context is OperationContext else {
            operation.cancel()
            return
        }
        
        switch context as! OperationContext {
        case .header:
            self.reader.send("\0A100\0".data(using: .ascii)!)
            self.reader.send("R".data(using: .ascii)!)
        default:
            fatalError()
        }
    }
    
    public func packetOperation(_ operation: Operation, didUpdate progress: Progress, with intent: Any?) {
        guard let intent = intent as? PacketIntent, case .read(_, let context?) = intent, context is OperationContext else {
            operation.cancel()
            return
        }
        print(progress.fractionCompleted)
        self.reader.send("1".data(using: .ascii)!)
    }
    
    public func packetOperation(_ operation: Operation, didComplete buffer: Data, with intent: Any?) {
        guard let intent = intent as? PacketIntent, case .read(_, let context?) = intent, context is OperationContext else {
            operation.cancel()
            return
        }
        
        print(GameboyClassic.Cartridge.Header(bytes: buffer))
        // self.close()
    }
    
    public func packetLength(for intent: Any?) -> UInt {
        guard let intent = intent as? PacketIntent else {
            fatalError()
        }
        
        switch intent {
        case .read:
            return 64
        case .write:
            return 1
        }
    }
    
}

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
        
        for _ in 0..<10 {
            let operation = SerialPacketOperation(controller: controller, delegate: controller, intent: .read(count: 80, context: OperationContext.header))
            controller.addOperation(operation)
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
