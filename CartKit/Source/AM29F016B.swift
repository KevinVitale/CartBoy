import Gibby

public protocol FlashCartridge: Gibby.Cartridge {
    init(contentsOf url: URL) throws
    var voltage: Voltage { get }
}

extension FlashCartridge {
    /// Override if the `Flash Cartridge` requires special consideration.
    public var voltage: Voltage {
        switch Platform.self {
        case is GameboyClassic.Type: return .high
        case is GameboyAdvance.Type: return .low
        default: fatalError("Unspecified platform: \(Platform.self)")
        }
    }
}

extension FlashCartridge {
    public static func load(_ url: URL) -> Result<Self,Error> {
        Result { try Self.init(contentsOf: url) }
    }
}

public struct AM29F016B: FlashCartridge {
    public init(contentsOf url: URL) throws {
        self = .init(bytes: try Data(contentsOf: url))
    }
    
    public init(bytes data: Data) {
        self.cartridge = Platform.Cartridge(bytes: data)
    }
    
    public typealias Platform = GameboyClassic
    public typealias Index    = Platform.Cartridge.Index
    
    private let cartridge: Platform.Cartridge

    public subscript(position: Index) -> Data.Element {
        return cartridge[Index(position)]
    }
    
    public var startIndex: Index {
        return Index(cartridge.startIndex)
    }
    
    public var endIndex: Index {
        return Index(cartridge.endIndex)
    }
    
    public func index(after i: Index) -> Index {
        return Index(cartridge.index(after: Int(i)))
    }
    
    public var fileExtension: String {
        return cartridge.fileExtension
    }
    
    public func write(to url: URL, options: Data.WritingOptions = []) throws {
        try self.cartridge.write(to: url, options: options)
    }
}

extension AM29F016B {
    static func erase(_ serialDevice: SerialDevice<GBxCart>) -> Result<(),Error> {
        serialDevice.waitFor(TerminatingResponse) {
            GBxCart.flash(serialDevice, byte: 0xF0, at: 0x00)
        }
        .flatMap { _ in GBxCart.flushBuffer(serialDevice, for: GameboyClassic.self) }
        .flatMap { _ in Result {
            serialDevice.send("G".bytes())  // romMode
            serialDevice.send("PW".bytes()) // pinMode
            }
        }
        .flatMap { _ in serialDevice.waitFor(TerminatingResponse) { GBxCart.flash(serialDevice, byte: 0xAA, at: 0x555) } }
        .flatMap { _ in serialDevice.waitFor(TerminatingResponse) { GBxCart.flash(serialDevice, byte: 0x55, at: 0x2AA) } }
        .flatMap { _ in serialDevice.waitFor(TerminatingResponse) { GBxCart.flash(serialDevice, byte: 0x80, at: 0x555) } }
        .flatMap { _ in serialDevice.waitFor(TerminatingResponse) { GBxCart.flash(serialDevice, byte: 0xAA, at: 0x555) } }
        .flatMap { _ in serialDevice.waitFor(TerminatingResponse) { GBxCart.flash(serialDevice, byte: 0x55, at: 0x2AA) } }
        .flatMap { _ in serialDevice.waitFor(TerminatingResponse) { GBxCart.flash(serialDevice, byte: 0x10, at: 0x555) } }
        .flatMap({ _ in
            /// Starts (and continues) erasing the memory off the flash chip. Stops when hitting '0xFF'.
            GBxCart.read(fromSerialDevice: serialDevice,
                      platform: GameboyClassic.self,
                      byteCount: 1,
                      startingAt: 0x0000,
                      responseEvaluator: {
                        guard $0!.starts(with: [0xFF]) else {
                            GBxCart.continue(serialDevice)
                            return false
                        }
                        return true })
        })
            .flatMap { _ in
                serialDevice.waitFor(TerminatingResponse) {
                    GBxCart.flash(serialDevice, byte: 0xF0, at: 0x00)
                }
                .map({ _ in })
        }
    }
    
    func flash(_ serialDevice: SerialDevice<GBxCart>,
              progress update: ((Double) -> ())?) -> Result<(),Error> {
        AM29F016B.erase(serialDevice)
            .flatMap { _ in
                GBxCart.flushBuffer(serialDevice, for: GameboyClassic.self)
                    .flatMap { _ in
                        let hexCodes = [ // '555'
                            (0x555, 0xAA),
                            (0x2AA, 0x55),
                            (0x555, 0xA0)
                        ]
                        return serialDevice.waitFor(TerminatingResponse) {
                            serialDevice.send("G".bytes())  // romMode
                            serialDevice.send("PW".bytes()) // pinMode
                            serialDevice.send("E".bytes())  // romMode
                            serialDevice.send("", number: hexCodes[0].0)
                        }
                        .flatMap { _ in serialDevice.waitFor(TerminatingResponse) { serialDevice.send("", number: hexCodes[0].1) } }
                        .flatMap { _ in serialDevice.waitFor(TerminatingResponse) { serialDevice.send("", number: hexCodes[1].0) } }
                        .flatMap { _ in serialDevice.waitFor(TerminatingResponse) { serialDevice.send("", number: hexCodes[1].1) } }
                        .flatMap { _ in serialDevice.waitFor(TerminatingResponse) { serialDevice.send("", number: hexCodes[2].0) } }
                        .flatMap { _ in serialDevice.waitFor(TerminatingResponse) { serialDevice.send("", number: hexCodes[2].1) } }
                        .map { _ in () }
                }
            }
            .flatMap({
                let progress = Progress(totalUnitCount: Int64(self.count))
                //--------------------------------------------------------------
                var observer: NSKeyValueObservation?
                if let update = update {
                    observer = progress.observe(\.fractionCompleted, options: [.new]) { _, change in
                        DispatchQueue.main.async {
                            update(change.newValue ?? 0)
                        }
                    }
                }
                defer { observer?.invalidate() }
                //--------------------------------------------------------------
                return Result {
                    let header = self.header
                    for bank in 0..<header.romBanks {
                        let startIndex = bank * header.romBankSize
                        let endIndex   = startIndex.advanced(by: header.romBankSize)
                        //------------------------------------------------------
                        let slice  = self[startIndex..<endIndex]
                        let romBankSize = Int64(slice.count)
                        //------------------------------------------------------
                        progress.becomeCurrent(withPendingUnitCount: romBankSize)
                        //------------------------------------------------------
                        _ = try await {
                            serialDevice.request(totalBytes: (slice.count / 64),
                                                 packetSize: 1,
                                                 prepare: { _ in
                                                    GBxCart.stopReading(from: serialDevice)
                                                    GBxCart.setBank(serialDevice, bank: bank, at: 0x2100)
                                                    GBxCart.seek(serialDevice, to: bank > 0 ? 0x4000 : 0x0000)
                                                    
                                                    let startAddress = slice.startIndex
                                                    let bytesInRange = startAddress..<(startAddress + 64)
                                                    let bytesToWrite = "T".data(using: .ascii)! + Data(slice[bytesInRange])
                                                    
                                                    serialDevice.send(bytesToWrite) },
                                                 progress: { _, progress in
                                                    let startAddress = Int((progress.completedUnitCount * 64).advanced(by: Int(slice.startIndex)))
                                                    let bytesInRange = startAddress..<(startAddress + 64)
                                                    let bytesToWrite = "T".data(using: .ascii)! + Data(slice[bytesInRange])
                                                    serialDevice.send(bytesToWrite) },
                                                 responseEvaluator: { _ in true },
                                                 result: $0)
                                .start()
                        }
                        //------------------------------------------------------
                        progress.resignCurrent()
                    }
                }
            })
    }}
