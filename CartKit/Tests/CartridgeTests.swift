import XCTest
import ORSSerial
import Gibby
import CartKit

class CartridgeTests: XCTestCase {
    func testSessionReadAdvanceHeader() {
        let exp = expectation(description: "")
        GBxCart.open { serialDevice in
            switch serialDevice.readHeader(forPlatform: GameboyAdvance.self) {
            case .success(let header): print(header)
            case .failure(let error):  XCTFail("\(error)")
            }
            exp.fulfill()
        }
        waitForExpectations(timeout: 20)
    }
    
    func testSessionReadClassicHeader() {
        let exp = expectation(description: "")
        GBxCart.open { serialDevice in
            switch serialDevice.readHeader(forPlatform: GameboyClassic.self) {
            case .success(let header): print(header)
            case .failure(let error):  XCTFail("\(error)")
            }
            exp.fulfill()
        }
        waitForExpectations(timeout: 20)
    }
    
    @available(OSX 10.15, *)
    func testSessionReadClassicCartridge() {
        let exp = expectation(description: "")
        GBxCart.open { serialDevice in
            switch serialDevice
                .readClassicCartridge (progress: { print($0.fractionCompleted) })
                .write                (toDirectoryPath: "/Users/kevin/Desktop")
                .check                (MD5: "b259feb41811c7e4e1dc20167985c84") /* Super Mario Land? */
            {
            case .success(let cartridge): print(cartridge)
            case .failure(let error):  XCTFail("\(error)")
            }

            exp.fulfill()
        }
        waitForExpectations(timeout: 300)
    }
    
    func testSessionReadClassicSaveFile() {
        let exp = expectation(description: "")
        GBxCart.open { serialDevice in
            switch serialDevice
                .readClassicSaveData (progress: { print($0.fractionCompleted) })
                .write               (toDirectoryPath: "/Users/kevin/Desktop",
                                             fileName: "POKEMON RED.sav")
            {
            case .success(let saveData): print(saveData)
            case .failure(let error):  XCTFail("\(error)")
            }
            
            exp.fulfill()
        }
        waitForExpectations(timeout: 300)
    }
    
    @available(OSX 10.15, *)
    func testSessionRestoreClassicSaveFile() {
        let exp = expectation(description: "")
        GBxCart.open { serialDevice in
            switch Result(catching: {
                try Data(contentsOf: URL(fileURLWithPath: "/Users/kevin/Desktop/POKEMON YELLOW.sav"))
            })
            .flatMap({
                serialDevice
                    .restoreClassicSaveData($0, progress: { print($0.fractionCompleted) })
                    .readClassicSaveData       (progress: { print($0.fractionCompleted) })
                    .map { $0.md5 ?? .init() }
            })
            {
            case .success(let results) :print(results.hexString(separator: ""))
            case .failure(let error)   :XCTFail("\(error)")
            }
            exp.fulfill()
        }
        waitForExpectations(timeout: 300)
    }
    
    @available(OSX 10.15, *)
    func testSessionDeleteClassicSaveFile() {
        let exp = expectation(description: "")
        GBxCart.open { serialDevice in
            switch serialDevice
                .deleteClassicSaveData(progress: { print($0.fractionCompleted) })
                .readClassicSaveData  (progress: { print($0.fractionCompleted) })
                .map({ $0.md5 ?? .init() })
            {
            case .success(let results) :print(results.hexString(separator: ""))
            case .failure(let error)   :XCTFail("\(error)")
            }
            exp.fulfill()
        }
        waitForExpectations(timeout: 300)
    }
    
    func testSessionEraseClassicFlashCartridge() {
        let exp = expectation(description: "")
        GBxCart.open { serialDevice in
            switch serialDevice
                .erase(flashCartridge: AM29F016B.self)
                .readHeader(forPlatform: GameboyClassic.self)
            {
            case .success(let header) :print(header)
            case .failure(let error)  :XCTFail("\(error)")
            }
            exp.fulfill()
        }
        waitForExpectations(timeout: 300)
    }
    
    func testSessionClassicFlashCartridge() {
        let exp = expectation(description: "")
        GBxCart.open { serialDevice in
            let openFile = Result {
                try FlashCartridge<AM29F016B>(filePath: "/Users/kevin/Desktop/POKEMON_SLV.gbc")
            }
            switch openFile
                .flatMap({ cartridge in
                    serialDevice
                        .erase(flashCartridge: AM29F016B.self)
                        .flash(cartridge: cartridge, progress: { print($0.fractionCompleted) })
                })
                .readHeader(forPlatform: GameboyClassic.self)
            {
            case .success(let header) :print(header)
            case .failure(let error)  :XCTFail("\(error)")
            }
            exp.fulfill()
        }
        waitForExpectations(timeout: 300)
    }
	
	
    func testSessionEraseClassicFlashCartridgeAM29LV160DB() {
        let exp = expectation(description: "")
        GBxCart.open { serialDevice in
            switch serialDevice
                .erase(flashCartridge: AM29LV160DB.self)
               // .readHeader(forPlatform: GameboyClassic.self) <-- Header will be blank, so readHeader Result is probably error!
            {
            case .success(let header) :print(header)
            case .failure(let error)  :XCTFail("\(error)")
            }
            exp.fulfill()
        }
        waitForExpectations(timeout: 300)
    }
    
    func testSessionClassicFlashCartridgeAM29LV160DB() {
        let exp = expectation(description: "")
        GBxCart.open { serialDevice in
            let openFile = Result {
                try FlashCartridge<AM29LV160DB>(filePath: "/Users/bbsan/Desktop/POKEMON_YEL.gbc")
            }
            switch openFile
                .flatMap({ cartridge in
                    serialDevice
                        .erase(flashCartridge: AM29LV160DB.self)
                        .flash(cartridge: cartridge, progress: { print($0.fractionCompleted) })
                })
                .readHeader(forPlatform: GameboyClassic.self)
            {
            case .success(let header) :print(header)
            case .failure(let error)  :XCTFail("\(error)")
            }
            exp.fulfill()
        }
        waitForExpectations(timeout: 300)
    }
    
    
    func testDetectFlashCartridge() {
        let exp = expectation(description: "")
        GBxCart.open { serialDevice in
            ChipsetFlashProgram.allFlashPrograms.forEach {
                switch serialDevice.detectFlashID(using: $0) {
                case .success(let flashID) :print("\($0): \(flashID)")
                case .failure(let error)   :XCTFail("\(error)")
                }
            }
            
            exp.fulfill()
        }
        waitForExpectations(timeout: 300)
    }
    
    func testDetectCartridgeMode() {
        let exp = expectation(description: "")
        GBxCart.open { serialDevice in
            switch serialDevice.readCartridgeMode() {
            case .success(let mode)  :print(mode)
            case .failure(let error) :XCTFail("\(error)")
            }
            exp.fulfill()
        }
        waitForExpectations(timeout: 300)
    }
    
    func testDetectPCBVersion() {
        let exp = expectation(description: "")
        GBxCart.open { serialDevice in
            switch serialDevice.readPCBVersion() {
            case .success(let version) :print(version)
            case .failure(let error)   :XCTFail("\(error)")
            }
            exp.fulfill()
        }
        waitForExpectations(timeout: 300)
    }
}
