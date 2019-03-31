import Gibby

extension InsideGadgetsCartridgeController where Cartridge.Platform == GameboyClassic {
    @discardableResult
    func restore(_ data: Data) -> Bool {
        return send("W".data(using: .ascii)! + data)
    }

    @discardableResult
    func set<Number>(bank: Number, at address: Cartridge.Platform.AddressSpace, timeout: UInt32 = 250) -> Bool where Number : FixedWidthInteger {
        return ( send("B", number: address, radix: 16, timeout: timeout)
            &&   send("B", number:    bank, radix: 10, timeout: timeout))
    }
    
    @discardableResult
    func toggleRAM(on enabled: Bool, timeout: UInt32 = 250) -> Bool {
        return set(bank: enabled ? 0x0A : 0x00, at: 0, timeout: timeout)
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
    func mbc2(fix header: GameboyClassic.Cartridge.Header) -> Bool {
        switch header.configuration {
        case .one, .two:
            return (
                self.go(to: 0x0)
             && self.read()
             && self.stop()
            )
        default:
            return false
        }
    }
}

extension InsideGadgetsCartridgeController where Cartridge: FlashCartridge, Cartridge.Platform == GameboyClassic {
    @discardableResult
    func flash<Number>(byte: Number, at address: Cartridge.Platform.AddressSpace, timeout: UInt32 = 250) -> Bool where Number : FixedWidthInteger {
        return ( send("F", number: address)
            &&   send("", number: byte)
        )
    }
    
}

