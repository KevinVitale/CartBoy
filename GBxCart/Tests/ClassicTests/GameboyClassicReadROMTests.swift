import XCTest
import ORSSerial
import Gibby
import GBxCartKit

fileprivate final class GameboyClassicReadROMTests: XCTestCase {
    private typealias Platform  = GameboyClassic
    private typealias Cartridge = Platform.Cartridge
    private typealias Header    = Platform.Header
    
    private let controller = GBxCartReaderController<Platform>()
    
    func testReadROM() {
        XCTAssertNoThrow(try controller.openReader(matching: .GBxCart))
        
        let expectiation = expectation(description: "ROM file was read")
        
        var rom: Cartridge! {
            didSet {
                expectiation.fulfill()
            }
        }

        controller.read(rom: .header) { (header: Header?) in
            guard let header = header, header.isLogoValid else {
                return
            }
            
            print("|-------------------------------------|")
            print("|  CONFIGURATION: \(header.configuration)")
            print(header)
            
            self.controller.read(rom: .range(0x000..<0x8000)) {
                rom = $0
            }
        }
        
        waitForExpectations(timeout: 5)
        
        XCTAssertNotNil(rom)
        
        if let rom = rom {
            print(rom)
        }
    }
}
