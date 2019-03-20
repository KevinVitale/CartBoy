import Foundation

extension GBxSerialPortController {
    enum Timeout: UInt32 {
        case short    = 250
        case medium   = 1000
        case long     = 5000
        case veryLong = 10000
    }
    
    final func timeout(_ timeout: Timeout = .short) {
        usleep(timeout.rawValue)
    }
}
