import Gibby

extension InsideGadgetsCartridgeController where Platform == GameboyClassic {
    @discardableResult
    func set<Number>(bank: Number, at address: Platform.AddressSpace, timeout: UInt32 = 250) -> Bool where Number : FixedWidthInteger {
        return ( send("B", number: address, radix: 16, timeout: timeout)
            &&   send("B", number:    bank, radix: 10, timeout: timeout))
    }

    @discardableResult
    func romMode() -> Bool {
        return send("G".bytes())
    }
    
    @discardableResult
    func pin(mode: String) -> Bool {
        return (
            send("P".bytes())
         && send(mode.bytes())
        )
    }

    @discardableResult
    func flash<Number>(byte: Number, at address: Platform.AddressSpace, timeout: UInt32 = 250) -> Bool where Number : FixedWidthInteger {
        return ( send("F", number: address)
            &&   send("", number: byte)
        )
    }
}
