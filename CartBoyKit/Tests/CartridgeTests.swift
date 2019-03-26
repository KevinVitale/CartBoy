import XCTest
import ORSSerial
import Gibby
import CartKit

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
    
    func testEraseCartridge() {
        let serialPort = try! GBxCartridgeController<AM29F016B>.controller()
        let controller = InsideGadgetsWriter<AM29F016B>.self
        let exp = expectation(description: "Test Board Info")
        controller.erase(using: serialPort) {
            defer { exp.fulfill() }
            print(#function)
            XCTAssertTrue($0)
        }.start()
        waitForExpectations(timeout: 300)
    }
}
