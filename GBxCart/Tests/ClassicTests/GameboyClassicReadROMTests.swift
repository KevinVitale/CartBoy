import XCTest
import ORSSerial
import Gibby
import GBxCartKit

@objc(GameboyClassicReadROMTests)
fileprivate final class GameboyClassicReadROMTests: XCTestCase {
    private typealias Platform  = GameboyClassic
    private typealias Cartridge = Platform.Cartridge
    private typealias Header    = Platform.Header
    
    private private(set) var controller: GBxCartReaderController<Platform>!
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
            controller.reader.close()
        }
    }
    
    func testReadHeader() {
        let expectiation = expectation(description: "Header was read")
        
        var romHeader: Header! {
            didSet {
                XCTAssertNotNil(romHeader)
                
                if let header = romHeader {
                    XCTAssertTrue(romHeader.isLogoValid)
                    
                    print("|-------------------------------------|")
                    print("|  CONFIGURATION: \(header.configuration)")
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
                }
                
                expectiation.fulfill()
            }
        }

        controller.readCartridge { (cartridge: Cartridge?) in
            rom = cartridge
        }
        
        waitForExpectations(timeout: 5)

        self.closePort = true
    }
}
