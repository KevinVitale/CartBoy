import XCTest
import ORSSerial
import Gibby
@testable import CartKit

protocol CartridgeReader {
    associatedtype Cartridge: Gibby.Cartridge
    func readHeader<Controller: SerialPortController>(using controller: Controller, result: @escaping (Cartridge.Header?) -> ()) -> Operation
    func readCartridge<Controller: SerialPortController>(using controller: Controller, with header: Cartridge.Header?, result: @escaping (Cartridge?) -> ()) -> Operation
}

protocol CartridgeArchiver {
    associatedtype Cartridge: Gibby.Cartridge
    func backupSave<Controller: SerialPortController>(using controller: Controller, with header: Cartridge.Header?, result: @escaping (Data?) -> ()) -> Operation
    func restoreSave<Controller: SerialPortController>(using controller: Controller, with header: Cartridge.Header?, result: @escaping (Bool) -> ()) -> Operation
    func deleteSave<Controller: SerialPortController>(using controller: Controller, with header: Cartridge.Header?, result: @escaping (Bool) -> ()) -> Operation
}

protocol CartridgeWriter {
    associatedtype FlashCartridge: CartKit.FlashCartridge
    static func erase<Controller: SerialPortController>(using controller: Controller, result: @escaping (Bool) -> ())
}

struct InsideGadgetsReader<Cartridge: Gibby.Cartridge>: CartridgeReader, CartridgeArchiver {
    func readHeader<Controller>(using controller: Controller, result: @escaping (Cartridge.Header?) -> ()) -> Operation where Controller: SerialPortController {
        fatalError("Controller does not platform: \(Cartridge.Platform.self)")
    }
    func readCartridge<Controller>(using controller: Controller, with header: Cartridge.Header?, result: @escaping (Cartridge?) -> ()) -> Operation where Controller : SerialPortController {
        fatalError("Controller does not platform: \(Cartridge.Platform.self)")
    }
    
    func backupSave<Controller>(using controller: Controller, with header: Cartridge.Header?, result: @escaping (Data?) -> ()) -> Operation where Controller : SerialPortController {
        fatalError("Controller does not platform: \(Cartridge.Platform.self)")
    }
    
    func restoreSave<Controller>(using controller: Controller, with header: Cartridge.Header?, result: @escaping (Bool) -> ()) -> Operation where Controller : SerialPortController {
        fatalError("Controller does not platform: \(Cartridge.Platform.self)")
    }
    
    func deleteSave<Controller>(using controller: Controller, with header: Cartridge.Header?, result: @escaping (Bool) -> ()) -> Operation where Controller : SerialPortController {
        fatalError("Controller does not platform: \(Cartridge.Platform.self)")
    }
}

extension InsideGadgetsReader where Cartridge.Platform == GameboyAdvance {
    func readHeader<Controller>(using controller: Controller, result: @escaping (Cartridge.Header?) -> ()) -> Operation where Controller: SerialPortController {
        return SerialPortOperation(controller: controller, progress: Progress(totalUnitCount: Int64(Cartridge.Platform.headerRange.count)), perform: { progress in
        }) { data in
            
        }
    }
}

extension InsideGadgetsReader where Cartridge.Platform == GameboyClassic {
    func readHeader<Controller>(using controller: Controller, result: @escaping (Cartridge.Header?) -> ()) -> Operation where Controller: SerialPortController {
        let timeout: UInt32 = 250
        return SerialPortOperation(controller: controller, progress: Progress(totalUnitCount: Int64(Cartridge.Platform.headerRange.count)), perform: { progress in
            guard progress.completedUnitCount > 0 else {
                controller.send("0".bytes(),  timeout: timeout)
                controller.send("B", number: 0x0000, radix: 16, terminate: true, timeout: timeout)
                controller.send("B", number: 000000, radix: 10, terminate: true, timeout: timeout)
                controller.send("A100\0".bytes(), timeout: timeout)
                controller.send("R".bytes(), timeout: timeout)
                return
            }
            guard progress.completedUnitCount % 64 == 0 else {
                return
            }
            controller.send("1".bytes(), timeout: timeout)
        }) { data in
            controller.send("0\0".bytes(), timeout: timeout)
            guard let data = data else {
                result(nil)
                return
            }
            
            result(.init(bytes: data))
        }
    }
    
    func readCartridge<Controller>(using controller: Controller, with header: Cartridge.Header? = nil, result: @escaping (Cartridge?) -> ()) -> Operation where Controller : SerialPortController {
        guard let header = header as? GameboyClassic.Cartridge.Header else {
            return self.readHeader(using: controller) {
                return self.readCartridge(using: controller, with: $0, result: result).start()
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
    
    func backupSave<Controller>(using controller: Controller, with header: Cartridge.Header? = nil, result: @escaping (Data?) -> ()) -> Operation where Controller : SerialPortController {
        guard let header = header as? GameboyClassic.Cartridge.Header else {
            return self.readHeader(using: controller) {
                return self.backupSave(using: controller, with: $0, result: result).start()
            }
        }
        print(header)
        return SerialPortOperation(controller: controller, progress: Progress(totalUnitCount: Int64(header.ramSize)), perform: { progress in
            guard progress.completedUnitCount > 0 else {
                controller.send("0\0".bytes(),  timeout: 0)

                switch header.configuration {
                //--------------------------------------------------------------
                // MBC2 "fix"
                //--------------------------------------------------------------
                case .one, .two:
                    //----------------------------------------------------------
                    // START; STOP
                    //----------------------------------------------------------
                    controller.send("0".bytes(), timeout: 0)
                    controller.send("A0\0".bytes(), timeout: 0)
                    controller.send("R".bytes(), timeout: 0)
                    controller.send("0\0".bytes(), timeout: 0)
                default: (/* do nothing */)
                }
                //--------------------------------------------------------------
                // SET: the 'RAM' mode (MBC1-ONLY)
                //--------------------------------------------------------------
                if case .one = header.configuration {
                    controller.send("B", number: 0x6000, radix: 16, terminate: true, timeout: 0)
                    controller.send("B", number: 1, radix: 10, terminate: true, timeout: 0)
                }
                
                //--------------------------------------------------------------
                // TOGGLE
                //--------------------------------------------------------------
                controller.send("B", number: 0x0000, radix: 16, terminate: true, timeout: 0)
                controller.send("B", number: 0x0A, radix: 10, terminate: true, timeout: 0)
                
                //--------------------------------------------------------------
                // BANK SWITCH
                //--------------------------------------------------------------
                controller.send("B", number: 0x4000, radix: 16, terminate: true, timeout: 0)
                controller.send("B", number: 0x0, radix: 10, terminate: true, timeout: 0)

                //--------------------------------------------------------------
                // START
                //--------------------------------------------------------------
                controller.send("AA000\0".bytes(), timeout: 0)
                controller.send("R".bytes(), timeout: 0)
                return
            }
            guard progress.completedUnitCount % 64 == 0 else {
                return
            }
            if case let bank = progress.completedUnitCount / Int64(header.ramBankSize), progress.completedUnitCount % Int64(header.ramBankSize) == 0 {
                print("#\(bank), \(progress.fractionCompleted)%")
                
                controller.send("0".bytes(), timeout: 0)
                controller.send("B", number: 0x4000, radix: 16, terminate: true, timeout: 0)
                controller.send("B", number: bank, radix: 10, terminate: true, timeout: 0)
                controller.send("AA000\0".bytes(), timeout: 250)
                controller.send("R".bytes(), timeout: 0)
            }
            else {
                controller.send("1".bytes(), timeout: 0)
            }
        }) { data in
            controller.send("0\0".bytes(), timeout: 0)
            result(data)
        }
    }
}

class CartridgeTests: XCTestCase {
    func testReadHeader() {
        let exp = expectation(description: "Reads Header")
        let serialPort = try! GBxCartridgeController<GameboyClassic.Cartridge>.controller()
        let controller = InsideGadgetsReader<GameboyClassic.Cartridge>()
        controller.readHeader(using: serialPort) { header in
            defer { exp.fulfill() }
            print(header!)
        }.start()
        waitForExpectations(timeout: 10)
    }
    
    func testReadCartridge() {
        let exp = expectation(description: "Reads Cartridge")
        let serialPort = try! GBxCartridgeController<GameboyClassic.Cartridge>.controller()
        let controller = InsideGadgetsReader<GameboyClassic.Cartridge>()
        //----------------------------------------------------------------------
        var cartridge: GameboyClassic.Cartridge!
        //----------------------------------------------------------------------
        controller.readCartridge(using: serialPort) {
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
    
    func testBackupSaveFile() {
        let exp = expectation(description: "Backup Save File")
        let serialPort = try! GBxCartridgeController<GameboyClassic.Cartridge>.controller()
        let controller = InsideGadgetsReader<GameboyClassic.Cartridge>()
        //----------------------------------------------------------------------
        var result: (header: GameboyClassic.Cartridge.Header?, saveFile: Data?) = (nil, nil)
        //----------------------------------------------------------------------
        controller.readHeader(using: serialPort) { header in
            result.header = header
            controller.backupSave(using: serialPort, with: header) {
                defer { exp.fulfill() }
                XCTAssertNotNil($0)
                result.saveFile = $0
                }.start()
        }.start()
        //----------------------------------------------------------------------
        waitForExpectations(timeout: 10)
        //----------------------------------------------------------------------
        guard case let (header?, data?) = result else {
            return
        }
        let MD5 = data.md5.hexString(separator: "").lowercased()
        print("MD5: \(MD5)")
        //----------------------------------------------------------------------
        var saveFileURL = URL(fileURLWithPath: "/Users/kevin/Desktop/\(header.title).sav")
        try! data.write(to: saveFileURL)
        saveFileURL = URL(fileURLWithPath: "/Users/kevin/Desktop/\(header.title).sav.bak")
        try! data.write(to: saveFileURL)
    }
}
