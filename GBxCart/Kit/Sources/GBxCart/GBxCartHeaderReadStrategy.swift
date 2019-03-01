import Gibby

enum GBxCartHeaderReadStrategy {
    static func classic(_ operation: ReadHeaderOperation<GBxCartReaderController<GameboyClassic>>) {
        operation.controller.sendHaltReading()
        operation.controller.sendGo(to: GameboyClassic.headerRange.lowerBound)
        operation.controller.sendBeginReading()
    }
    
     static func advance(_ operation: ReadHeaderOperation<GBxCartReaderController<GameboyClassic>>) {
    }
}
