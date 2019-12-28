import XCTest
import ORSSerial
import Gibby
import CartKit

extension Cartridge {
    fileprivate var md5String: String {
        return Data(self[0..<self.endIndex]).md5.hexString(separator: "").lowercased()
    }
}

extension Data {
    fileprivate var md5String: String {
        return self.md5.hexString(separator: "").lowercased()
    }
}

fileprivate func saveFileAndMD5(named title: String, extension fileExtension: String = "sav") throws -> (data: Data, md5: String) {
    let data = try Data(contentsOf: URL(fileURLWithPath: "/Users/kevin/Desktop/\(title).\(fileExtension)"))
    let MD5 = data.md5.hexString(separator: "").lowercased()
    return (data, MD5)
}

fileprivate func saveFileAndMD5Result(named title: String, extension fileExtension: String = "sav") -> Result<(data: Data, md5: String),Error> {
    Result {
        try saveFileAndMD5(named: title, extension: fileExtension)
    }
}

fileprivate func romFileURL(named title: String, extension fileExtension: String = "gbc") -> URL {
    return URL(fileURLWithPath: "/Users/kevin/Desktop/\(title).\(fileExtension)")
}

class CartridgeTests: XCTestCase {
    func testHeader() {
        switch SerialDevice<GBxCart>
            .connect()
            .header(forPlatform: GameboyClassic.self)
        {
        case .success(let header): print(header)
        case .failure(let error):  XCTFail("\(error)")
        }
    }
    
    func testCartridge() {
        switch SerialDevice<GBxCart>
            .connect()
            .cartridge(forPlatform: GameboyClassic.self)
        {
        case .success(let cartridge): print(cartridge.header); print(cartridge.md5String)
        case .failure(let error):  XCTFail("\(error)")
        }
    }
    
    func testCartridgeAsync() {
        let exp = expectation(description: "")
        DispatchQueue.global(qos: .userInitiated).async {
            defer { exp.fulfill() }
            switch SerialDevice<GBxCart>
                .connect()
                .cartridge(forPlatform: GameboyClassic.self, progress: { print($0) })
            {
            case .success(let cartridge): print(cartridge.header); print(cartridge.md5String)
            case .failure(let error):  XCTFail("\(error)")
            }
        }
        waitForExpectations(timeout: 20)
    }
    
    func testBackupSave() {
        switch SerialDevice<GBxCart>
            .connect()
            .backupSave(for: GameboyClassic.self)
        {
        case .success(let saveData): print(saveData.md5String)
        case .failure(let error):  XCTFail("\(error)")
        }
    }
    
    func testBackupSaveAsync() {
        let exp = expectation(description: "")
        DispatchQueue.global(qos: .userInitiated).async {
            defer { exp.fulfill() }
            switch SerialDevice<GBxCart>
                .connect()
                .backupSave(for: GameboyClassic.self, progress: { print($0) })
            {
            case .success(let saveData): print(saveData.md5String)
            case .failure(let error):  XCTFail("\(error)")
            }
        }
        waitForExpectations(timeout: 20)
    }
    
    func testRestoreSave() {
        switch saveFileAndMD5Result(named: "POKEMON YELLOW")
            .flatMap({
                SerialDevice<GBxCart>
                    .connect()
                    .restoreSave(for: GameboyClassic.self, data: $0.data)
            })
        {
        case .success: ()
        case .failure(let error):  XCTFail("\(error)")
        }
    }
    
    func testRestoreSaveAsync() {
        let exp = expectation(description: "")
        DispatchQueue.global(qos: .userInitiated).async {
            defer { exp.fulfill() }
            switch saveFileAndMD5Result(named: "POKEMON YELLOW")
                .flatMap({
                    SerialDevice<GBxCart>
                        .connect()
                        .restoreSave( for: GameboyClassic.self,
                                     data: $0.data,
                                 progress: { print($0) } )
                })
            {
            case .success: ()
            case .failure(let error):  XCTFail("\(error)")
            }
        }
        waitForExpectations(timeout: 5)
    }
    
    func testDeleteSave() {
        switch SerialDevice<GBxCart>
            .connect()
            .deleteSave(for: GameboyClassic.self)
        {
        case .success: (/* no-op */)
        case .failure(let error):  XCTFail("\(error)")
        }
    }
    
    func testDeleteSaveAsync() {
        let exp = expectation(description: "")
        DispatchQueue.global(qos: .userInitiated).async {
            defer { exp.fulfill() }
            switch SerialDevice<GBxCart>
                .connect()
                .deleteSave( for: GameboyClassic.self, progress: { print($0) })
            {
            case .success: ()
            case .failure(let error):  XCTFail("\(error)")
            }
        }
        waitForExpectations(timeout: 5)
    }
    
    func testBoardVersion() {
        switch SerialDevice<GBxCart>
            .connect()
            .version()
        {
        case .success(let voltage): print(voltage)
        case .failure(let error):  XCTFail("\(error)")
        }
    }
    
    func testVoltage() {
        switch SerialDevice<GBxCart>
            .connect()
            .voltage()
        {
        case .success(let voltage): print(voltage)
        case .failure(let error):  XCTFail("\(error)")
        }
    }
    
    func testChipsetFlash_AM29F016B() {
        switch Result(catching: {
            try AM29F016B(contentsOf: romFileURL(named: "POKEMON YELLOW"))
        })
        .flatMap({
            SerialDevice
                .connect()
                .write(flashCartridge: $0)
        })
        {
        case .success: (/* no-op */)
        case .failure(let error): XCTFail("\(error)")
        }
    }
    
    func testChipsetFlash_AM29F016B_Async() {
        let exp = expectation(description: "")
        DispatchQueue.global(qos: .userInitiated).async {
            defer { exp.fulfill() }
            switch Result(catching: {
                try AM29F016B(contentsOf: romFileURL(named: "POKEMON YELLOW"))
            })
                .flatMap({
                    SerialDevice
                        .connect()
                        .write(flashCartridge: $0, progress: { print($0) })
                })
            {
            case .success: (/* no-op */)
            case .failure(let error): XCTFail("\(error)")
            }
        }
        waitForExpectations(timeout: 300)
    }
    
    func testChipsetErase_AM29F016B() {
        switch SerialDevice<GBxCart>
            .connect()
            .erase(flashCartridge: AM29F016B.self)
        {
        case .success: ()
        case .failure(let error):  XCTFail("\(error)")
        }
    }
}
