import Gibby

public protocol CartridgeController: SerialPortController {
    associatedtype Platform: Gibby.Platform
}
