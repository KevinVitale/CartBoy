import XCTest
import ORSSerial
import Gibby

fileprivate final class GameboyClassicReadROMTests: XCTestCase {
    private typealias Platform = GameboyClassic
    private typealias Header = Platform.Header
    
    private let controller = TestReaderController<Platform>()
    
    func testReadHeader() {
        XCTAssertNoThrow(try controller.openReader(matching: .GBxCart))
        
        let expectiation = expectation(description: "ROM header was read")
        
        var header: Header! {
            didSet {
                expectiation.fulfill()
            }
        }
        
        controller.read(rom: .header) {
            header = $0
        }
        
        waitForExpectations(timeout: 5)

        XCTAssertNotNil(header)
        
        if let header = header {
            print(header)
        }
    }
}
