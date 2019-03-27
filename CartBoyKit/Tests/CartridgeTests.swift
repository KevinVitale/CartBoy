import XCTest
import ORSSerial
import Gibby
import CartKit

class CartridgeTests: XCTestCase {
    func testReadHeader() {
        let exp = expectation(description: "Reads Header")
        let serialPort = try! InsideGadgetsCartridgeController.controller()
        let controller = InsideGadgetsReader<GameboyClassic.Cartridge>()
        controller.readHeader(using: serialPort) { header in
            defer { exp.fulfill() }
            print(header!)
        }.start()
        waitForExpectations(timeout: 10)
    }
    
    func testReadCartridge() {
        let exp = expectation(description: "Reads Cartridge")
        let serialPort = try! InsideGadgetsCartridgeController.controller()
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
        waitForExpectations(timeout: 100)
        //----------------------------------------------------------------------
        guard cartridge != nil else {
            return
        }
        print("MD5:", Data(cartridge[0..<cartridge.endIndex]).md5.hexString(separator: "").lowercased())
        print(String(repeating: "-", count: 45), "|", separator: "")
        print(cartridge!)
        print(String(repeating: "-", count: 45), "|", separator: "")
        try! cartridge.write(to: URL(fileURLWithPath: "/Users/kevin/Desktop/\(cartridge.header.title).gb"))
    }
    
    func testBackupSaveFile() {
        let exp = expectation(description: "Backups Save File")
        let serialPort = try! InsideGadgetsCartridgeController.controller()
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
    
    func testRestoreSaveFile() {
        let exp = expectation(description: "Restores Save File")
        exp.expectedFulfillmentCount = 3
        //----------------------------------------------------------------------
        let serialPort = try! InsideGadgetsCartridgeController.controller()
        let controller = InsideGadgetsReader<GameboyClassic.Cartridge>()
        //----------------------------------------------------------------------
        func saveFileAndMD5(named title: String, extension fileExtension: String = "sav.bak") throws -> (data: Data, md5: String) {
            let data = try Data(contentsOf: URL(fileURLWithPath: "/Users/kevin/Desktop/\(title).\(fileExtension)"))
            let MD5 = data.md5.hexString(separator: "").lowercased()
            return (data, MD5)
        }
        //----------------------------------------------------------------------
        let saveFile = try! saveFileAndMD5(named: "PM_CRYSTAL")
        print("MD5: \(saveFile.md5)")
        //----------------------------------------------------------------------
        // Read (cache) the cartridge header
        controller.readHeader(using: serialPort) { header in
            defer { exp.fulfill() }
            XCTAssertNotNil(header)
            // Write the save file
            controller.restoreSave(data: saveFile.data, using: serialPort, with: header) {
                defer { exp.fulfill() }
                XCTAssertTrue($0)
                // Sanity-Check
                controller.backupSave(using: serialPort, with: header) {
                    defer { exp.fulfill() }
                    XCTAssertNotNil($0)
                    let data = $0 ?? Data()
                    let md5 = data.md5.hexString(separator: "").lowercased()
                    print("WAS: \(saveFile.md5)")
                    print("NOW: \(md5)")
                    }.start()
                }.start()
        }.start()
        //----------------------------------------------------------------------
        waitForExpectations(timeout: 10)
        //----------------------------------------------------------------------
    }
    
    func testDeleteSaveFile() {
        let exp = expectation(description: "Deletes Save File")
        //----------------------------------------------------------------------
        let serialPort = try! InsideGadgetsCartridgeController.controller()
        let controller = InsideGadgetsReader<GameboyClassic.Cartridge>()
        //----------------------------------------------------------------------
        controller.deleteSave(using: serialPort) {
            defer { exp.fulfill() }
            XCTAssertTrue($0)
        }.start()
        //----------------------------------------------------------------------
        waitForExpectations(timeout: 10)
        //----------------------------------------------------------------------
    }

    func testEraseCartridge() {
        let exp = expectation(description: "Erase Cartridge")
        //----------------------------------------------------------------------
        let serialPort = try! InsideGadgetsCartridgeController.controller()
        let controller = InsideGadgetsWriter<AM29F016B>.self
        //----------------------------------------------------------------------
        controller.erase(using: serialPort) {
            defer { exp.fulfill() }
            print(#function)
            XCTAssertTrue($0)
        }.start()
        //----------------------------------------------------------------------
        waitForExpectations(timeout: 300)
        //----------------------------------------------------------------------
    }
    
    func testWriteCartridge() {
        let exp = expectation(description: "Erase Cartridge")
        exp.expectedFulfillmentCount = 3
        //----------------------------------------------------------------------
        let serialPort = try! InsideGadgetsCartridgeController.controller()
        let writer = InsideGadgetsWriter<AM29F016B>()
        let reader = InsideGadgetsReader<GameboyClassic.Cartridge>()
        //----------------------------------------------------------------------
        // TODO: Extend 'CartridgeWrite' so that it loads flash carts!
        //----------------------------------------------------------------------
        func romFileURL(named title: String, extension fileExtension: String = "gb") -> URL {
            return URL(fileURLWithPath: "/Users/kevin/Desktop/\(title).\(fileExtension)")
        }
        let flashCart = try! writer.read(contentsOf: romFileURL(named: "ZELDA"))
        //----------------------------------------------------------------------
        InsideGadgetsWriter<AM29F016B>.erase(using: serialPort) {
            defer { exp.fulfill() }
            print(#function)
            XCTAssertTrue($0)
            writer.write(flashCartridge: flashCart, using: serialPort) {
                defer { exp.fulfill() }
                XCTAssertTrue($0)
                reader.readHeader(using: serialPort) {
                    defer { exp.fulfill() }
                    print(#function)
                    XCTAssertNotNil($0)
                    guard let header = $0 else {
                        return
                    }
                    XCTAssertEqual(header.title, flashCart.header.title)
                    }.start()
                }.start()
        }.start()
        //----------------------------------------------------------------------
        waitForExpectations(timeout: 300)
        //----------------------------------------------------------------------
    }
}
