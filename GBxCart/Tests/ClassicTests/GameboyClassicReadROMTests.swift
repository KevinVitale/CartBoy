import XCTest
import ORSSerial
import Gibby
import GBxCartKit

@objc(GameboyClassicReadROMTests)
fileprivate final class GameboyClassicReadROMTests: XCTestCase {
    private typealias Cartridge = GameboyClassic.Cartridge
    private typealias Header    = Cartridge.Header
    
    private private(set) var controller: GBxCartReaderController<Cartridge>!
    private var closePort = false
    
    override func setUp() {
        do {
            if controller == nil {
                controller = try GBxCartReaderController()
            }
        }
        catch {
            fatalError("GBxCart reader was not found. Please connect it to your computer and try again.")
        }
    }

    override func tearDown() {
        if closePort {
            controller.closePort()
        }
    }
    
    func testReadHeader() {
        let expectiation = expectation(description: "Header was read")
        
        var romHeader: Header! {
            didSet {
                XCTAssertNotNil(romHeader)
                
                if let header = romHeader {
                    XCTAssertTrue(romHeader.isLogoValid)
                    
                    if let header = header as? GameboyClassic.Cartridge.Header {
                        print("|-------------------------------------|")
                        print("|  CONFIGURATION: \(header.configuration)")
                    }
                    print(header)
                }

                expectiation.fulfill()
            }
        }
        
        controller.readHeader { (header: Header?) in
            romHeader = header
        }
        
        waitForExpectations(timeout: 5)
    }

    func testReadROM() {
        let expectiation = expectation(description: "ROM file was read")
        
        var rom: Cartridge! {
            didSet {
                XCTAssertNotNil(rom)

                if let rom = rom {
                    print(rom)
                    if rom.header.isLogoValid {
                        if let header = rom.header.self as? GameboyClassic.Cartridge.Header {
                            print("|-------------------------------------|")
                            print("|  CONFIGURATION: \(header.configuration)")
                        }
                        print(rom.header)
                        try! rom.write(to: URL(fileURLWithPath: "/Users/kevin/Desktop/\(rom.header.title).gb"))
                    }
                    else {
                        XCTFail("Invalid ROM header.")
                    }
                }
                
                expectiation.fulfill()
            }
        }

        controller.readCartridge { (cartridge: Cartridge?) in
            rom = cartridge
        }
        
        waitForExpectations(timeout: 60)
    }
    
    func testReadSaveFile() {
        let expectiation = expectation(description: "ROM file was read")
        
        var saveFile: (Data?, Header?) {
            didSet {
                XCTAssertNotNil(saveFile)
                
                if case let (saveFile?, header?) = saveFile {
                    if saveFile.isEmpty == false {
                        print(saveFile)
                        try! saveFile.write(to: URL(fileURLWithPath: "/Users/kevin/Desktop/\(header.title).sav"))
                    }
                    else {
                        XCTFail("Invalid save data.")
                    }
                }
                
                expectiation.fulfill()
            }
        }
        
        controller.readSaveFile { (data: Data?, header: Header) in
            saveFile = (data, header)
        }
        
        waitForExpectations(timeout: 60)
        
        self.closePort = true
    }
}
