import XCTest
import ORSSerial
import Gibby
import CartKit

class CartridgeTests: XCTestCase {
    func testSessionReadClassicHeader() {
        let exp = expectation(description: "")
        SerialDeviceSession<GBxCart>.open { serialDevice in
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
        SerialDeviceSession<GBxCart>.open { serialDevice in
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
        SerialDeviceSession<GBxCart>.open { serialDevice in
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
        SerialDeviceSession<GBxCart>.open { serialDevice in
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
        SerialDeviceSession<GBxCart>.open { serialDevice in
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
}
