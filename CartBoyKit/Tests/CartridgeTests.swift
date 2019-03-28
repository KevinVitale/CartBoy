import XCTest
import ORSSerial
import Gibby
import CartKit

class CartridgeTests: XCTestCase {
    func testReadHeader() {
        let exp = expectation(description: "Reads Header")
        let controller = try! InsideGadgetsCartridgeController.reader(for: GameboyClassic.Cartridge.self)
        controller.readHeader { header in
            defer { exp.fulfill() }
            print(header!)
        }.start()
        waitForExpectations(timeout: 10)
    }
    
    func testReadCartridge() {
        let exp = expectation(description: "Reads Cartridge")
        let controller = try! InsideGadgetsCartridgeController.reader(for: GameboyClassic.Cartridge.self)
        //----------------------------------------------------------------------
        var cartridge: GameboyClassic.Cartridge!
        //----------------------------------------------------------------------
        controller.readCartridge {
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
        let controller = try! InsideGadgetsCartridgeController.reader(for: GameboyClassic.Cartridge.self)
        //----------------------------------------------------------------------
        var result: (header: GameboyClassic.Cartridge.Header?, saveFile: Data?) = (nil, nil)
        //----------------------------------------------------------------------
        controller.readHeader { header in
            result.header = header
            controller.backupSave(with: header) {
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
        exp.expectedFulfillmentCount = 2
        //----------------------------------------------------------------------
        let controller = try! InsideGadgetsCartridgeController.reader(for: GameboyClassic.Cartridge.self)
        //----------------------------------------------------------------------
        func saveFileAndMD5(named title: String, extension fileExtension: String = "sav") throws -> (data: Data, md5: String) {
            let data = try Data(contentsOf: URL(fileURLWithPath: "/Users/kevin/Desktop/\(title).\(fileExtension)"))
            let MD5 = data.md5.hexString(separator: "").lowercased()
            return (data, MD5)
        }
        //----------------------------------------------------------------------
        let saveFile = try! saveFileAndMD5(named: "POKEMON BLUE")
        print("MD5: \(saveFile.md5)")
        //----------------------------------------------------------------------
        // Read (cache) the cartridge header
        controller.readHeader { header in
            defer { exp.fulfill() }
            XCTAssertNotNil(header)
            // Write the save file
            controller.restoreSave(data: saveFile.data, with: header) {
                defer { exp.fulfill() }
                XCTAssertTrue($0)
                }.start()
        }.start()
        //----------------------------------------------------------------------
        waitForExpectations(timeout: 10)
        //----------------------------------------------------------------------
    }
    
    func testDeleteSaveFile() {
        let exp = expectation(description: "Deletes Save File")
        //----------------------------------------------------------------------
        let controller = try! InsideGadgetsCartridgeController.reader(for: GameboyClassic.Cartridge.self)
        //----------------------------------------------------------------------
        controller.deleteSave {
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
        exp.expectedFulfillmentCount = 4
        //----------------------------------------------------------------------
        let writer = try! InsideGadgetsCartridgeController.writer(for: AM29F016B.self)
        let reader = try! InsideGadgetsCartridgeController.reader(for: AM29F016B.self)
        reader.readHeader {
            defer { exp.fulfill() }
            if $0?.isLogoValid == false {
                print("WARNING: Invalid header. Flashing cart will likely fail.")
                print($0 ?? .init(bytes: Data()))
            }
            else {
                print("Logo: OK!")
            }
        }.start()
        //----------------------------------------------------------------------
        // TODO: Extend 'CartridgeWrite' so that it loads flash carts!
        //----------------------------------------------------------------------
        func romFileURL(named title: String, extension fileExtension: String = "gb") -> URL {
            return URL(fileURLWithPath: "/Users/kevin/Desktop/\(title).\(fileExtension)")
        }
        let flashCart = try! writer.read(contentsOf: romFileURL(named: "POKEMON RED"))
        //----------------------------------------------------------------------
        // FIX ME! Don't use 'controller' anymore
        InsideGadgetsWriter<AM29F016B>.erase(using: try! InsideGadgetsCartridgeController.controller()) {
            defer { exp.fulfill() }
            print(#function)
            XCTAssertTrue($0)
            writer.write(flashCart) {
                defer { exp.fulfill() }
                XCTAssertTrue($0)
                reader.readHeader {
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
