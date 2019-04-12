import Gibby

extension InsideGadgetsCartridgeController {
    @discardableResult
    func go(to address: Platform.AddressSpace, timeout: UInt32 = 250) -> Bool {
        return send("A", number: address, timeout: timeout)
    }
    
    @discardableResult
    func read() -> Bool {
        switch Platform.self {
        case is GameboyClassic.Type:
            return send("R".bytes())
        case is GameboyAdvance.Type:
            return send("r".bytes())
        default:
            return false
        }
    }
    
    @discardableResult
    func stop(timeout: UInt32 = 0) -> Bool {
        return send("0".bytes(), timeout: timeout)
    }
    
    @discardableResult
    func `continue`() -> Bool {
        return send("1".bytes())
    }
}
