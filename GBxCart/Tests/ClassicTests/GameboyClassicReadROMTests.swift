import XCTest
import ORSSerial
import Gibby
import GBxCartKit

fileprivate final class GameboyClassicReadROMTests: XCTestCase {
    private typealias Platform  = GameboyClassic
    private typealias Cartridge = Platform.Cartridge
    private typealias Header    = Platform.Header
    
    private let controller = GBxCartReaderController<Platform>()
    private var closePort = false

    override func tearDown() {
        if closePort {
            controller.reader?.close()
        }
    }
    
    func testReadHeader() {
        XCTAssertNoThrow(try controller.openReader(matching: .GBxCart))
        
        let expectiation = expectation(description: "Header was read")
        
        var romHeader: Header! {
            didSet {
                expectiation.fulfill()
            }
        }
        
        controller.readHeader { (header: Header?) in
            guard let header = header, header.isLogoValid else {
                return
            }
            
            print("|-------------------------------------|")
            print("|  CONFIGURATION: \(header.configuration)")
            print(header)
            romHeader = header
        }
        
        waitForExpectations(timeout: 5)
        XCTAssertNotNil(romHeader)
    }
    
    func testReadROM() {
        XCTAssertNoThrow(try controller.openReader(matching: .GBxCart))
        
        let expectiation = expectation(description: "ROM file was read")
        
        var rom: Cartridge! {
            didSet {
                expectiation.fulfill()
            }
        }

        controller.readCartridge { (cartridge: Cartridge?) in
            if let cartridge = cartridge {
                rom = cartridge
            }
        }
        
        waitForExpectations(timeout: 5)
        
        XCTAssertNotNil(rom)
        
        if let rom = rom {
            print(rom)
        }
        
        self.closePort = true
    }
}
