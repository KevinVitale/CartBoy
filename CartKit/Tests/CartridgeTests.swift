import XCTest
import ORSSerial
import Gibby
import CartKit

extension Cartridge {
    fileprivate var md5String: String {
        return Data(self[0..<self.endIndex]).md5.hexString(separator: "").lowercased()
    }
}

fileprivate func saveFileAndMD5(named title: String, extension fileExtension: String = "sav") throws -> (data: Data, md5: String) {
    let data = try Data(contentsOf: URL(fileURLWithPath: "/Users/kevin/Desktop/\(title).\(fileExtension)"))
    let MD5 = data.md5.hexString(separator: "").lowercased()
    return (data, MD5)
}

fileprivate func romFileURL(named title: String, extension fileExtension: String = "gb") -> URL {
    return URL(fileURLWithPath: "/Users/kevin/Desktop/\(title).\(fileExtension)")
}

class CartridgeTests: XCTestCase {
    func testHeader() {
        let exp = expectation(description: "")
        insideGadgetsController.perform { controller in
            defer { exp.fulfill() }
            switch controller.flatMap({ $0.header(for: GameboyClassic.self) }) {
            case .success(let header): print(header)
            case .failure(let error):  XCTFail("\(error)")
            }
        }
        waitForExpectations(timeout: 5)
    }
    
    func testCartridge() {
        let exp = expectation(description: "")
        insideGadgetsController.perform { controller in
            defer { exp.fulfill() }
            switch controller
                .flatMap({ $0.cartridge(for: GameboyClassic.self, progress: { print($0) }) })
            {
            case .success(let cartridge): print(cartridge.header); print(cartridge.md5String)
            case .failure(let error):  XCTFail("\(error)")
            }
        }
        waitForExpectations(timeout: 20)
    }
    
    func testBackupSave() {
        let exp = expectation(description: "")
        insideGadgetsController.perform { controller in
            defer { exp.fulfill() }
            switch controller.flatMap({ $0.backupSave(for: GameboyClassic.self, progress: { print($0) }) }) {
            case .success(let saveData): print(saveData)
            case .failure(let error):  XCTFail("\(error)")
            }
        }
        waitForExpectations(timeout: 20)
    }
    
    func testRestoreSave() {
        let exp = expectation(description: "")
        insideGadgetsController.perform { controller in
            defer { exp.fulfill() }
            switch controller
                .flatMap({ controller in Result { (controller, try saveFileAndMD5(named: "POKEMON YELLOW")) } })
                .flatMap({ $0.restoreSave(for: GameboyClassic.self, data: $1.data, progress: { print($0) }) })
            {
            case .success: ()
            case .failure(let error):  XCTFail("\(error)")
            }
        }
        waitForExpectations(timeout: 5)
    }
    
    func testDeleteSave() {
        let exp = expectation(description: "")
        insideGadgetsController.perform { controller in
            defer { exp.fulfill() }
            switch controller.flatMap({ $0.deleteSave(for: GameboyClassic.self, progress: { print($0) })})
            {
            case .success: ()
            case .failure(let error):  XCTFail("\(error)")
            }
        }
        waitForExpectations(timeout: 5)
    }
    
    func testVoltage() {
        let exp = expectation(description: "")
        insideGadgetsController.perform { controller in
            defer { exp.fulfill() }
            switch controller.flatMap({ $0.voltage() })
            {
            case .success(let voltage): print(voltage)
            case .failure(let error):  XCTFail("\(error)")
            }
        }
        waitForExpectations(timeout: 5)
    }
    
    func testWriteResult() {
        let exp = expectation(description: "")
        insideGadgetsController.perform { controller in
            defer { exp.fulfill() }
            switch controller
                .map({ controller in (controller, "POKEMON YELLOW") })
                .flatMap({ (controller, fileName) in Result { (controller, try AM29F016B(contentsOf: romFileURL(named: fileName))) } })
                .flatMap({ (controller, flashCartridge) in controller.write(to: flashCartridge, progress: { print($0) }) })
            {
            case .success: ()
            case .failure(let error):  XCTFail("\(error)")
            }
        }
        waitForExpectations(timeout: 300)
    }
    
    func testCartridgeEraser() {
        let exp = expectation(description: "")
        insideGadgetsController.perform { controller in
            defer { exp.fulfill() }
            switch controller.flatMap({ $0.erase(chipset: AM29F016B.self) }) {
            case .success: ()
            case .failure(let error):  XCTFail("\(error)")
            }
        }
        waitForExpectations(timeout: 20)
    }
}
