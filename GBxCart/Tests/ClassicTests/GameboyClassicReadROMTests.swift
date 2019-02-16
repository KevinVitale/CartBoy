import XCTest
import ORSSerial
import Gibby

class GameboyClassicReadROMTests: BaseReadROMTest<GameboyClassic> {
    func testReadHeader() {
        XCTAssertNoThrow(try openReader(matching: .GBxCart))
        
    }
}
