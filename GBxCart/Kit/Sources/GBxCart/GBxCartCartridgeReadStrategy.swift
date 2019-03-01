import Gibby

enum GBxCartCartridgeReadStrategy {
    static func classic(_ operation: ReadCartridgeOperation<GBxCartReaderController<GameboyClassic>>) {
        operation.controller.sendHaltReading()
        
        // Enumerate the each bank-switch, reading memory from it.
        // for currentBank in 1..<GameboyClassic.AddressSpace(operation.header.romBanks) {
        for currentBank in 0xc..<0xd {
            print("Bank: \(currentBank)")
            
            /**
             The first bank reads 32KB, and 16KB thereafter (`bankBytesToRead`).
             A starting address is also determined. For the bank being read:
             - Bank #1 starts reading at '0'; or,
             - Bank #2 and above starts reading at byte '16384' (0x4000).
             */
            operation.bankBytesToRead = currentBank > 1 ? 0x4000 : 0x8000
            
            if case .one = operation.header.configuration {
                operation.controller.sendSwitch(bank: 0, at: 0x6000)
                operation.controller.sendSwitch(bank: GameboyClassic.AddressSpace(currentBank >> 5), at: 0x4000)
                operation.controller.sendSwitch(bank: GameboyClassic.AddressSpace(currentBank & 0x1F), at: 0x2000)
            }
            else {
                operation.controller.sendSwitch(bank: GameboyClassic.AddressSpace(currentBank), at: 0x2100)
                if currentBank >= 0x100 {
                    operation.controller.sendSwitch(bank: 1, at: 0x3000)
                }
            }
            
            let address = GameboyClassic.AddressSpace(currentBank > 1 ? 0x4000 : 0x0000)
            operation.controller.sendGo(to: GameboyClassic.AddressSpace(address))
            operation.controller.sendBeginReading()
            
            operation.readCondition.wait()
            operation.controller.sendHaltReading()
            let prefix = operation.bytesRead.suffix(from: operation.bytesRead.count - 0x4000).map { String($0, radix: 16, uppercase: true)}.joined(separator: " ")
            print(#function, operation.bytesRead, prefix.prefix(0x40))
        }
    }
    
    static func advance(_ operation: ReadCartridgeOperation<GBxCartReaderController<GameboyClassic>>) {
    }
}
