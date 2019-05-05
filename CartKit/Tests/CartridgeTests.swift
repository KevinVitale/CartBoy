import XCTest
import ORSSerial
import Gibby
import CartKit

extension Cartridge {
    fileprivate var md5: String {
        return Data(self[0..<self.endIndex]).md5.hexString(separator: "").lowercased()
    }
}

class CartridgeTests: XCTestCase {
    func testHeaderResult() {
        let exp = expectation(description: "")
        do {
            let controller = try insideGadgetsController<GameboyClassic>()
            controller.scanHeader {
                switch $0 {
                case .success(let header):
                    print(header)
                    exp.fulfill()
                case .failure(let error):
                    XCTFail("\(error)")
                    exp.fulfill()
                }
            }
        } catch {
            XCTFail("\(error)")
            exp.fulfill()
        }
        waitForExpectations(timeout: 5)
    }
    
    func testCartridgeResult() {
        let exp = expectation(description: "")
        do {
            let controller = try insideGadgetsController<GameboyClassic>()
            controller.readCartridge(progress: {
                print($0)
            }) {
                switch $0 {
                case .success(let cartridge):
                    print("MD5:", cartridge.md5)
                    exp.fulfill()
                case .failure(let error):
                    XCTFail("\(error)")
                    exp.fulfill()
                }
            }
        } catch {
            XCTFail("\(error)")
            exp.fulfill()
        }
        waitForExpectations(timeout: 20)
    }
    
    func testBackupResult() {
        let exp = expectation(description: "")
        
        do {
            let controller = try insideGadgetsController<GameboyClassic>()
            controller.backupSave(progress: {
                print($0)
            }) {
                switch $0 {
                case .success(let saveData):
                    print("MD5:", saveData.md5.hexString(separator: "").lowercased())
                    exp.fulfill()
                case .failure(let error):
                    XCTFail("\(error)")
                    exp.fulfill()
                }
            }
        } catch {
            XCTFail("\(error)")
            exp.fulfill()
        }
        waitForExpectations(timeout: 5)
    }
    
    func testRestoreResult() {
        let exp = expectation(description: "")
        switch InsideGadgetsCartridgeController<GameboyClassic>.reader() {
        case .failure(let error):
            XCTFail("\(error)")
            exp.fulfill()
        case .success(let reader):
            //------------------------------------------------------------------
            func saveFileAndMD5(named title: String, extension fileExtension: String = "sav") throws -> (data: Data, md5: String) {
                let data = try Data(contentsOf: URL(fileURLWithPath: "/Users/kevin/Desktop/\(title).\(fileExtension)"))
                let MD5 = data.md5.hexString(separator: "").lowercased()
                return (data, MD5)
            }
            //------------------------------------------------------------------
            let saveFile = try! saveFileAndMD5(named: "POKEMON YELLOW")
            print("MD5: \(saveFile.md5)")
            reader.restore(data: saveFile.data, progress: {
                print($0)
            }) {
                switch $0 {
                case .failure(let error):
                    XCTFail("\(error)")
                    exp.fulfill()
                case .success:
                    exp.fulfill()
                }
            }
        }
        waitForExpectations(timeout: 5)
    }
    
    func testDeleteResult() {
        let exp = expectation(description: "")
        switch InsideGadgetsCartridgeController<GameboyClassic>.reader() {
        case .failure(let error):
            XCTFail("\(error)")
            exp.fulfill()
        case .success(let reader):
            reader.delete(progress: {
                print($0)
            }) {
                switch $0 {
                case .failure(let error):
                    XCTFail("\(error)")
                    exp.fulfill()
                case .success:
                    exp.fulfill()
                }
            }
        }
        waitForExpectations(timeout: 5)
    }
    
    func testEraseResult() {
        let exp = expectation(description: "")
        switch InsideGadgetsCartridgeController.writer(for: AM29F016B.self) {
        case .failure(let error):
            XCTFail("\(error)")
            exp.fulfill()
        case .success(let writer):
            var observer: NSKeyValueObservation!
            writer.erase(progress: {
                observer = $0.observe(\.fractionCompleted, options: [.new]) { progress, change in
                    print(change.newValue ?? 0)
                }
            }) {
                defer { observer.invalidate() }
                switch $0 {
                case .failure(let error):
                    XCTFail("\(error)")
                    exp.fulfill()
                case .success:
                    exp.fulfill()
                }
            }
        }
        waitForExpectations(timeout: 300)
    }
    
    func testWriteResult() {
        let exp = expectation(description: "")

        func romFileURL(named title: String, extension fileExtension: String = "gb") -> URL {
            return URL(fileURLWithPath: "/Users/kevin/Desktop/\(title).\(fileExtension)")
        }

        switch InsideGadgetsCartridgeController
            .writer(for: AM29F016B.self)
            .flatMap({ $0.read(contentsOf: romFileURL(named: "POKEMON YELLOW")) })
        {
        case .failure(let error):
            XCTFail("\(error)")
            exp.fulfill()
        case .success(let result):
            var observer: NSKeyValueObservation!
            result.0.write(result.1, progress: {
                observer = $0.observe(\.fractionCompleted, options: [.new]) { progress, change in
                    print(change.newValue ?? 0)
                }
            }) {
                defer { observer.invalidate() }
                switch $0 {
                case .failure(let error):
                    XCTFail("\(error)")
                    exp.fulfill()
                case .success:
                    exp.fulfill()
                }
            }
        }
        
        waitForExpectations(timeout: 300)
    }
    
    func testVersionResult() {
        let exp = expectation(description: "Reads Controller Version")
        InsideGadgetsCartridgeController<GameboyClassic>.version {
            defer { exp.fulfill() }
            switch $0 {
            case .failure(let error):
                XCTFail("\(error)")
            case .success(let version):
                print(version)
            }
        }
        waitForExpectations(timeout: 10)
    }
}
