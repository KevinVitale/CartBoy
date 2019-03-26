import XCTest
import ORSSerial
import Gibby
@testable import CartKit

protocol CartridgeReader {
    associatedtype Cartridge: Gibby.Cartridge
    func readHeader<Controller: SerialPortController>(from controller: Controller, result: @escaping (Cartridge.Header?) -> ()) -> Operation
    func readCartridge<Controller: SerialPortController>(from controller: Controller, with header: Cartridge.Header?, result: @escaping (Cartridge?) -> ()) -> Operation
}

protocol CartridgeWriter {
    associatedtype FlashCartridge: CartKit.FlashCartridge
    static func erase<Controller: SerialPortController>(using controller: Controller, result: @escaping (Bool) -> ())
}

struct InsideGadgetsController<Cartridge: Gibby.Cartridge>: CartridgeReader {
    func readHeader<Controller>(from controller: Controller, result: @escaping (Cartridge.Header?) -> ()) -> Operation where Controller: SerialPortController {
        fatalError("Controller does not platform: \(Cartridge.Platform.self)")
    }
    func readCartridge<Controller>(from controller: Controller, with header: Cartridge.Header?, result: @escaping (Cartridge?) -> ()) -> Operation where Controller : SerialPortController {
        fatalError("Controller does not platform: \(Cartridge.Platform.self)")
    }
}

extension InsideGadgetsController where Cartridge.Platform == GameboyAdvance {
    func readHeader<Controller>(from controller: Controller, result: @escaping (Cartridge.Header?) -> ()) -> Operation where Controller: SerialPortController {
        return SerialPortOperation(controller: controller, progress: Progress(totalUnitCount: Int64(Cartridge.Platform.headerRange.count)), perform: { progress in
        }) { data in
            
        }
    }
}

extension InsideGadgetsController where Cartridge.Platform == GameboyClassic {
    func readHeader<Controller>(from controller: Controller, result: @escaping (Cartridge.Header?) -> ()) -> Operation where Controller: SerialPortController {
        return SerialPortOperation(controller: controller, progress: Progress(totalUnitCount: Int64(Cartridge.Platform.headerRange.count)), perform: { progress in
            guard progress.completedUnitCount > 0 else {
                controller.send("0\0".bytes(),  timeout: 0)
                controller.send("B", number: 0x0000, radix: 16, terminate: true, timeout: 0)
                controller.send("B", number: 000000, radix: 10, terminate: true, timeout: 0)
                controller.send("A100\0".bytes(), timeout: 0)
                controller.send("R".bytes(),    timeout: 0)
                return
            }
            guard progress.completedUnitCount % 64 == 0 else {
                return
            }
            controller.send("1".bytes(), timeout: 0)
        }) { data in
            controller.send("0".bytes(), timeout: 0)
            guard let data = data else {
                result(nil)
                return
            }
            
            result(.init(bytes: data))
        }
    }
    
    func readCartridge<Controller>(from controller: Controller, with header: Cartridge.Header? = nil, result: @escaping (Cartridge?) -> ()) -> Operation where Controller : SerialPortController {
        guard let header = header as? GameboyClassic.Cartridge.Header else {
            return self.readHeader(from: controller) {
                return self.readCartridge(from: controller, with: $0, result: result).start()
            }
        }
        print(header)
        return SerialPortOperation(controller: controller, progress: Progress(totalUnitCount: Int64(header.romSize)), perform: { progress in
            guard progress.completedUnitCount > 0 else {
                controller.send("0".bytes(),  timeout: 0)
                controller.send("B", number: 0x0000, radix: 16, terminate: true, timeout: 0)
                controller.send("B", number: 000000, radix: 10, terminate: true, timeout: 0)
                controller.send("A0\0".bytes(), timeout: 250)
                controller.send("R".bytes(), timeout: 0)
                return
            }
            guard progress.completedUnitCount % 64 == 0 else {
                return
            }
            if case let bank = progress.completedUnitCount / Int64(header.romBankSize), bank >= 1, progress.completedUnitCount % Int64(header.romBankSize) == 0 {
                controller.send("0\0".bytes(), timeout: 0)
                switch header.configuration {
                case .one:
                    controller.send("B", number: 0x6000, radix: 16, terminate: true, timeout: 0)
                    controller.send("B", number: bank, radix: 10, terminate: true, timeout: 0)
                    
                    controller.send("B", number: 0x4000, radix: 16, terminate: true, timeout: 0)
                    controller.send("B", number: bank >> 5, radix: 10, terminate: true, timeout: 0)
                    
                    controller.send("B", number: 0x2000, radix: 16, terminate: true, timeout: 0)
                    controller.send("B", number: (bank & 0x1F), radix: 10, terminate: true, timeout: 0)
                default:
                    controller.send("B", number: 0x2100, radix: 16, terminate: true, timeout: 0)
                    controller.send("B", number: bank, radix: 10, terminate: true, timeout: 0)
                    if bank >= 0x100 {
                        controller.send("B", number: 0x3000, radix: 16, terminate: true, timeout: 0)
                        controller.send("B", number: 1, radix: 10, terminate: true, timeout: 0)
                    }
                }
                print(".", separator: "", terminator: "")
                controller.send("A4000\0".bytes(), timeout: 0)
                controller.send("R".bytes(),    timeout: 0)
            }
            else {
                controller.send("1".bytes(), timeout: 0)
            }
        }) { data in
            controller.send("0\0".bytes(), timeout: 0)
            guard let data = data else {
                result(nil)
                return
            }
            
            result(.init(bytes: data))
        }
    }
}

class CartridgeTests: XCTestCase {
    func testReadHeader() {
        let exp = expectation(description: "Reads Header")
        let serialPort = try! GBxCartridgeController<GameboyClassic.Cartridge>.controller()
        let controller = InsideGadgetsController<GameboyClassic.Cartridge>()
        controller.readHeader(from: serialPort) { header in
            defer { exp.fulfill() }
            print(header!)
        }.start()
        waitForExpectations(timeout: 10)
    }
    
    func testReadCartridge() {
        let exp = expectation(description: "Reads Cartridge")
        let serialPort = try! GBxCartridgeController<GameboyClassic.Cartridge>.controller()
        let controller = InsideGadgetsController<GameboyClassic.Cartridge>()
        //----------------------------------------------------------------------
        var cartridge: GameboyClassic.Cartridge!
        //----------------------------------------------------------------------
        controller.readCartridge(from: serialPort) {
            defer { exp.fulfill() }
            XCTAssertNotNil($0)
            cartridge = $0
            }.start()
        //----------------------------------------------------------------------
        waitForExpectations(timeout: 20)
        //----------------------------------------------------------------------
        guard cartridge != nil else {
            return
        }
        print("MD5:", Data(cartridge[0..<cartridge.endIndex]).md5.hexString(separator: "").lowercased())
        print(String(repeating: "-", count: 45), "|", separator: "")
        print(cartridge)
        print(String(repeating: "-", count: 45), "|", separator: "")
        try! cartridge.write(to: URL(fileURLWithPath: "/Users/kevin/Desktop/\(cartridge.header.title).gb"))
    }
}
