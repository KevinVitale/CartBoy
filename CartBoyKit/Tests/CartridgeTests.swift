import XCTest
import ORSSerial
import Gibby
@testable import CartKit

class CartridgeTests: XCTestCase {
    func testReadHeader() {
        let exp = expectation(description: "Reads Header")
        let controller = try! InsideGadgetsCartridgeController<GameboyClassic.Cartridge>.reader()
        controller.readHeader { header in
            defer { exp.fulfill() }
            print(header!)
        }
        waitForExpectations(timeout: 10)
    }

    func testReadCartridge() {
        let exp = expectation(description: "Reads Cartridge")
        let controller = try! InsideGadgetsCartridgeController<GameboyClassic.Cartridge>.reader()
        //----------------------------------------------------------------------
        var cartridge: GameboyClassic.Cartridge!
        //----------------------------------------------------------------------
        controller.readCartridge {
            defer { exp.fulfill() }
            XCTAssertNotNil($0)
            cartridge = $0
        }
        let observer = controller.progress.observe(\.fractionCompleted, options: [.new, .old]) { progress, change in
            let newValue = change.newValue ?? 0
            let oldValue = change.oldValue ?? 0
            if newValue != oldValue {
                print(newValue)
            }
        }
        //----------------------------------------------------------------------
        waitForExpectations(timeout: 100)
        //----------------------------------------------------------------------
        observer.invalidate()
        //----------------------------------------------------------------------
        guard cartridge != nil else {
            return
        }
        print("MD5:", Data(cartridge[0..<cartridge.endIndex]).md5.hexString(separator: "").lowercased())
        print(String(repeating: "-", count: 45), "|", separator: "", terminator: "\n")
        print(cartridge!)
        print(cartridge!.header)
        print(String(repeating: "-", count: 45), "|", separator: "", terminator: "\n")
        try! cartridge.write(to: URL(fileURLWithPath: "/Users/kevin/Desktop/\(cartridge.header.title).gb"))
    }

    func testBackupSaveFile() {
        let exp = expectation(description: "Backups Save File")
        let controller = try! InsideGadgetsCartridgeController<GameboyClassic.Cartridge>.reader()
        //----------------------------------------------------------------------
        var result: (header: GameboyClassic.Cartridge.Header?, saveFile: Data?) = (nil, nil)
        //----------------------------------------------------------------------
        controller.readHeader { header in
            result.header = header
            controller.backupSave(with: header) {
                defer { exp.fulfill() }
                XCTAssertNotNil($0)
                result.saveFile = $0
            }
        }
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
        let controller = try! InsideGadgetsCartridgeController<GameboyClassic.Cartridge>.reader()
        //----------------------------------------------------------------------
        func saveFileAndMD5(named title: String, extension fileExtension: String = "sav") throws -> (data: Data, md5: String) {
            let data = try Data(contentsOf: URL(fileURLWithPath: "/Users/kevin/Desktop/\(title).\(fileExtension)"))
            let MD5 = data.md5.hexString(separator: "").lowercased()
            return (data, MD5)
        }
        //----------------------------------------------------------------------
        let saveFile = try! saveFileAndMD5(named: "MARIO DELUX")
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
            }
        }
        //----------------------------------------------------------------------
        waitForExpectations(timeout: 10)
        //----------------------------------------------------------------------
    }
    
    func testDeleteSaveFile() {
        let exp = expectation(description: "Deletes Save File")
        //----------------------------------------------------------------------
        let controller = try! InsideGadgetsCartridgeController<GameboyClassic.Cartridge>.reader()
        //----------------------------------------------------------------------
        controller.deleteSave {
            defer { exp.fulfill() }
            XCTAssertTrue($0)
        }
        //----------------------------------------------------------------------
        waitForExpectations(timeout: 10)
        //----------------------------------------------------------------------
    }

    func testEraseCartridge() {
        let exp = expectation(description: "Erase Cartridge")
        //----------------------------------------------------------------------
        let controller = try! InsideGadgetsCartridgeController<AM29F016B>.writer()
        //----------------------------------------------------------------------
        controller.erase {
            defer { exp.fulfill() }
            print(#function)
            XCTAssertTrue($0)
        }
        //----------------------------------------------------------------------
        let observer = controller.progress.observe(\.fractionCompleted, options: [.new]) { progress, change in
            print(change.newValue ?? 0)
        }
        //----------------------------------------------------------------------
        waitForExpectations(timeout: 300)
        //----------------------------------------------------------------------
        observer.invalidate()
    }
    
    func testEraseAndWriteCartridge() {
        let exp = expectation(description: "Erase Cartridge")
        exp.expectedFulfillmentCount = 2
        //----------------------------------------------------------------------
        let writer = try! InsideGadgetsCartridgeController<AM29F016B>.writer()
        //----------------------------------------------------------------------
        // TODO: Extend 'CartridgeWrite' so that it loads flash carts!
        //----------------------------------------------------------------------
        func romFileURL(named title: String, extension fileExtension: String = "gb") -> URL {
            return URL(fileURLWithPath: "/Users/kevin/Desktop/\(title).\(fileExtension)")
        }
        let flashCart = try! writer.read(contentsOf: romFileURL(named: "MARIO DELUX"))
        //----------------------------------------------------------------------
        print("MD5:", Data(flashCart[0..<flashCart.endIndex]).md5.hexString(separator: "").lowercased())
        print(String(repeating: "-", count: 45), "|", separator: "", terminator: "\n")
        print(flashCart)
        print(flashCart.header)
        print(String(repeating: "-", count: 45), "|", separator: "", terminator: "\n")
        //----------------------------------------------------------------------
        writer.erase {
            defer { exp.fulfill() }
            print(#function)
            XCTAssertTrue($0)
            writer.write(flashCart) {
                defer { exp.fulfill() }
                XCTAssertTrue($0)
            }
        }
        let observer = writer.progress.observe(\.fractionCompleted, options: [.new, .old]) { progress, change in
            let newValue = change.newValue ?? 0
            let oldValue = change.oldValue ?? 0
            if newValue != oldValue {
                print(newValue)
            }
        }
        //----------------------------------------------------------------------
        waitForExpectations(timeout: 300)
        //----------------------------------------------------------------------
        observer.invalidate()
    }
    
    func testWriteCartridge() {
        let exp = expectation(description: "Erase Cartridge")
        //----------------------------------------------------------------------
        let writer = try! InsideGadgetsCartridgeController<AM29F016B>.writer()
        //----------------------------------------------------------------------
        // TODO: Extend 'CartridgeWrite' so that it loads flash carts!
        //----------------------------------------------------------------------
        func romFileURL(named title: String, extension fileExtension: String = "gb") -> URL {
            return URL(fileURLWithPath: "/Users/kevin/Desktop/\(title).\(fileExtension)")
        }
        let flashCart = try! writer.read(contentsOf: romFileURL(named: "MARIO DELUX"))
        //----------------------------------------------------------------------
        print("MD5:", Data(flashCart[0..<flashCart.endIndex]).md5.hexString(separator: "").lowercased())
        print(String(repeating: "-", count: 45), "|", separator: "", terminator: "\n")
        print(flashCart)
        print(flashCart.header)
        print(String(repeating: "-", count: 45), "|", separator: "", terminator: "\n")
        //----------------------------------------------------------------------
        writer.write(flashCart) {
            defer { exp.fulfill() }
            XCTAssertTrue($0)
        }
        let observer = writer.progress.observe(\.fractionCompleted, options: [.new, .old]) { progress, change in
            let newValue = change.newValue ?? 0
            let oldValue = change.oldValue ?? 0
            if newValue != oldValue {
                print(newValue)
            }
        }
        //----------------------------------------------------------------------
        waitForExpectations(timeout: 300)
        //----------------------------------------------------------------------
        observer.invalidate()
    }
}
