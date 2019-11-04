import ORSSerial
import Gibby

//MARK: - insideGadgetsController (Class) -
public final class insideGadgetsController: ThreadSafeSerialPortController {
    override init(matching portProfile: ORSSerialPortManager.PortProfile = .usb(vendorID: 6790, productID: 29987)) throws {
        try super.init(matching: portProfile)
    }
    
    public override func open() -> ORSSerialPort {
        return super.open().configuredAsGBxCart()
    }
    
    public func boardVersion() -> Result<Data, Swift.Error> {
        precondition(Thread.current != .main)
        return Result {
            try await {
                self.request(totalBytes: 1
                    , packetSize: 1
                    , prepare: { _ in
                        self.send("h\0".bytes())
                    }
                    , progress: { _, _ in }
                    , responseEvaluator: { _ in true }
                    , result: $0)
                    .start()
            }
        }
    }
    
    public func set(voltage: Voltage) -> Result<Data, Swift.Error> {
        precondition(Thread.current != .main)
        return self.boardVersion().flatMap {
            switch $0.hexString() {
            case "1": fallthrough
            case "2": return .success(Data())
            default:
                _ = try? Result {
                    try await {
                        self.request(totalBytes: 1
                            , packetSize: 1
                            , timeoutInterval: 0.5
                            , prepare: { _ in
                                let byteCmd = voltage == .low ? "3" : "5"
                                self.send("\(byteCmd)\0".bytes(), timeout: 500)
                        }
                            , progress: { _, _ in }
                            , responseEvaluator: { _ in true }
                            , result: $0)
                            .start()
                    }
                }.get()
                return .success(Data())
            }
        }
    }

    public func voltage() -> Result<Voltage, Error> {
        precondition(Thread.current != .main)
        return Result {
            try await {
                self.request(totalBytes: 1
                    , packetSize: 1
                    , prepare: { _ in
                        self.send("C\0".bytes())
                }
                    , progress: { _, _ in }
                    , responseEvaluator: { _ in true }
                    , result: $0)
                    .start()
            }
            }
            .flatMap {
                guard let voltage = Voltage($0.first ?? .min) else {
                    return .failure(VoltageError.invalidVoltage)
                }
                return .success(voltage)
        }
    }
}

//MARK: - insideGadgetsController (CatridgeController) -
extension insideGadgetsController: CartridgeController {
    public static func perform(on queue: DispatchQueue = DispatchQueue(label: ""), _ block: @escaping (Result<insideGadgetsController, Error>) -> ()) {
        queue.async {
            block(Result { try .init() })
        }
    }
    
    public func header<Platform: Gibby.Platform>(for platform: Platform.Type) -> Result<Platform.Header, Error> {
        return self
            .verify(platform: platform)
            .flatMap {
                self.read(platform: $0
                    , byteCount: Platform.headerRange.count
                    , startingAt: Platform.headerRange.lowerBound
                    , prepare: {
                        switch platform {
                        case is GameboyClassic.Type: self.toggleRAM(on: false)
                        default: (/* no-op */)
                        }
                })
            }
            .flatMap { data in
                let header = platform.Header(bytes: data)
                guard header.isLogoValid else {
                    return .failure(CartridgeControllerError<Platform>.invalidHeader)
                }
                return .success(header)
        }
    }
    
    public func cartridge<Platform: Gibby.Platform>(for platform: Platform.Type, progress update: @escaping (Double) -> ()) -> Result<Platform.Cartridge, Error> {
        return .failure(CartridgeControllerError.platformNotSupported(platform))
    }
    
    public func cartridge(for platform: GameboyClassic.Type, progress update: @escaping (Double) -> ()) -> Result<GameboyClassic.Cartridge, Error> {
        return self
            .header(for: platform)
            .map { ($0, Progress(totalUnitCount: Int64($0.romSize))) }
            .flatMap { (header, progress) in
                //--------------------------------------------------------------
                let observer = progress.observe(\.fractionCompleted, options: [.new]) { _, change in
                    DispatchQueue.main.async {
                        update(change.newValue ?? 0)
                    }
                }
                //--------------------------------------------------------------
                defer { observer.invalidate() }
                //--------------------------------------------------------------
                return Result {
                    var romData = Data()
                    for bank in 0..<header.romBanks {
                        progress.becomeCurrent(withPendingUnitCount: Int64(header.romBankSize))
                        //--------------------------------------------------------------
                        let bankData = try self.read(platform: GameboyClassic.self
                            , byteCount: header.romBankSize
                            , startingAt: bank > 0 ? 0x4000 : 0x0000
                            , prepare: {
                                self.mbc2(fix: header)
                                //------------------------------------------------------
                                guard bank > 0 else { return }
                                //------------------------------------------------------
                                if case .one = header.configuration {
                                    self.set(bank:           0, at: 0x6000)
                                    self.set(bank:   bank >> 5, at: 0x4000)
                                    self.set(bank: bank & 0x1F, at: 0x2000)
                                }
                                else {
                                    self.set(bank: bank, at: 0x2100)
                                    if bank > 0x100 {
                                        self.set(bank: 1, at: 0x3000)
                                    }
                                }
                        }).get()
                        //--------------------------------------------------------------
                        romData.append(bankData)
                        //--------------------------------------------------------------
                        progress.resignCurrent()
                    }
                    return romData
                }
            }
            .map { .init(bytes: $0) }
    }
    
    public func backupSave<Platform: Gibby.Platform>(for platform: Platform.Type, progress: @escaping (Double) -> ()) -> Result<Data, Error> {
        switch platform {
        case is GameboyClassic.Type:
            return self.backupSave(for: GameboyClassic.self, progress: progress)
        default:
            return .failure(CartridgeControllerError.platformNotSupported(platform))
        }
    }
    
    private func backupSave(for platform: GameboyClassic.Type, progress update: @escaping (Double) -> ()) -> Result<Data, Error> {
        return self
            .header(for: platform)
            .map { ($0, Progress(totalUnitCount: Int64($0.ramSize))) }
            .flatMap { (header, progress) in
                //--------------------------------------------------------------
                let observer = progress.observe(\.fractionCompleted, options: [.new]) { _, change in
                    DispatchQueue.main.sync {
                        update(change.newValue ?? 0)
                    }
                }
                //--------------------------------------------------------------
                defer { observer.invalidate() }
                //--------------------------------------------------------------
                return Result {
                    let ramBankSize = Int64(header.ramBankSize)
                    var backupData = Data()
                    for bank in 0..<header.ramBanks {
                        //------------------------------------------------------
                        progress.becomeCurrent(withPendingUnitCount: ramBankSize)
                        //------------------------------------------------------
                        let bankData = try self.read(platform: platform
                            , byteCount: ramBankSize
                            , startingAt: 0xA000
                            , prepare: {
                                self.mbc2(fix: header)
                                //----------------------------------------------
                                // SET: the 'RAM' mode (MBC1-ONLY)
                                //----------------------------------------------
                                if case .one = header.configuration {
                                    self.set(bank: 1, at: 0x6000)
                                }
                                //----------------------------------------------
                                self.toggleRAM(on: true)
                                self.set(bank: bank, at: 0x4000)
                        }).get()
                        //------------------------------------------------------
                        backupData.append(bankData)
                        //------------------------------------------------------
                        progress.resignCurrent()
                    }
                    return backupData
                }
        }
    }
    
    public func restoreSave<Platform: Gibby.Platform>(for platform: Platform.Type, data: Data, progress: @escaping (Double) -> ()) -> Result<(), Error> {
        switch platform {
        case is GameboyClassic.Type:
            return self.restoreSave(for: GameboyClassic.self, data: data, progress: progress)
        default:
            return .failure(CartridgeControllerError.platformNotSupported(platform))
        }
    }
    
    private func restoreSave(for platform: GameboyClassic.Type, data: Data, progress update: @escaping (Double) -> ()) -> Result<(), Error> {
        return self
            .header(for: platform)
            .map { ($0, Progress(totalUnitCount: Int64($0.ramSize))) }
            .flatMap { (header, progress) in
                //--------------------------------------------------------------
                let observer = progress.observe(\.fractionCompleted, options: [.new]) { _, change in
                    DispatchQueue.main.sync {
                        update(change.newValue ?? 0)
                    }
                }
                //--------------------------------------------------------------
                defer { observer.invalidate() }
                //--------------------------------------------------------------
                return Result {
                    for bank in 0..<header.ramBanks {
                        let startIndex = bank * header.ramBankSize
                        let endIndex   = startIndex.advanced(by: header.ramBankSize)
                        //--------------------------------------------------------------
                        let slice  = data[startIndex..<endIndex]
                        let ramBankSize = Int64(slice.count)
                        //--------------------------------------------------------------
                        progress.becomeCurrent(withPendingUnitCount: ramBankSize)
                        //--------------------------------------------------------------
                        _ = try await {
                            self.request(totalBytes: ramBankSize / 64
                                , packetSize: 1
                                , prepare: { _ in
                                    if bank == 0 { self.toggleRAM(on: true) }
                                    //--------------------------------------------------
                                    self.stop()
                                    self.mbc2(fix: header)
                                    //--------------------------------------------------
                                    // SET: the 'RAM' mode (MBC1-ONLY)
                                    //--------------------------------------------------
                                    if case .one = header.configuration {
                                        self.set(bank: 1, at: 0x6000)
                                    }
                                    //--------------------------------------------------
                                    self.set(bank: bank, at: 0x4000)
                                    self.go(to: 0xA000)
                                    self.send(saveData: slice[slice.startIndex..<slice.startIndex.advanced(by: 64)])
                            }
                                , progress: { _, progress in
                                    let startAddress = Int(progress.completedUnitCount * 64).advanced(by: slice.startIndex)
                                    let rangeOfBytes = startAddress..<Int(startAddress + 64)
                                    self.send(saveData: slice[rangeOfBytes])
                            }
                                , responseEvaluator: { _ in true }
                                , result: $0)
                                .start()
                        }
                        //--------------------------------------------------------------
                        progress.resignCurrent()
                    }
                }
        }
    }
    
    public func deleteSave<Platform: Gibby.Platform>(for platform: Platform.Type, progress updating: @escaping (Double) -> ()) -> Result<(), Error> {
        switch platform {
        case is GameboyClassic.Type:
            return self
                .header(for: GameboyClassic.self)
                .flatMap { self.restoreSave(for: GameboyClassic.self, data: Data(count: $0.ramSize), progress: updating) }
        default:
            return .failure(CartridgeControllerError.platformNotSupported(platform))
        }
    }

    public func erase<FlashCartridge: CartKit.FlashCartridge>(chipset: FlashCartridge.Type) -> Result<(), Error> {
        return .failure(CartridgeFlashError.unsupportedChipset(chipset))
    }
    
    public func erase<FlashCartridge: CartKit.FlashCartridge>(chipset: FlashCartridge.Type) -> Result<(), Error> where FlashCartridge.Platform == GameboyClassic {
        return self
            .resetFlashModeResult(chipset)
            .flatMap { _ in self.flushBuffer(for: chipset.Platform.self) }
            .flatMap { _ in self.sendEraseFlashProgramResult(chipset) }
            .flatMap { _ in
                self.read(platform: chipset.Platform.self
                    , byteCount: 1
                    , startingAt: 0x0000
                    , timeout: 30
                    , responseEvaluator: {
                        guard $0!.starts(with: [0xFF]) else {
                            self.continue()
                            return false
                        }
                        return true
                })
            }
            .flatMap { _ in self.resetFlashModeResult(chipset) }
            .map { _ in () }
    }

    public func write<FlashCartridge: CartKit.FlashCartridge>(to flashCartridge: FlashCartridge, progress: @escaping (Double) -> ()) -> Result<(), Error> {
        return .failure(CartridgeFlashError.unsupportedChipset(type(of: flashCartridge)))
    }
    
    public func write(to flashCartridge: AM29F016B, progress update: @escaping (Double) -> ()) -> Result<(), Error> {
        return self.erase(chipset: AM29F016B.self)
            .flatMap { self.flushBuffer(for: AM29F016B.Platform.self).map { _ in } }
            .flatMap { self.sendWriteFlashProgram(for: AM29F016B.self) }
            .map     { Progress(totalUnitCount: Int64(flashCartridge.count)) }
            .flatMap { progress in
                //--------------------------------------------------------------
                let observer = progress.observe(\.fractionCompleted, options: [.new]) { _, change in
                    DispatchQueue.main.sync {
                        update(change.newValue ?? 0)
                    }
                }
                //--------------------------------------------------------------
                defer { observer.invalidate() }
                //--------------------------------------------------------------
                return self.flash(flashCartridge, progress: progress)
        }
    }
}

//MARK: - insideGadgetsController (Shared) -
extension insideGadgetsController {
    fileprivate func read<Platform: Gibby.Platform, Number>(platform: Platform.Type, byteCount: Number, startingAt address: Platform.AddressSpace, timeout: TimeInterval = -1.0, prepare: (() -> ())? = nil, progress update: @escaping (Progress) -> () = { _ in }, responseEvaluator: @escaping ORSSerialPacketEvaluator = { _ in true }) -> Result<Data, Error> where Number: FixedWidthInteger {
        precondition(Thread.current != .main)
        return Result {
            let data = try await {
                self.request(totalBytes: byteCount
                    , packetSize: 64
                    , timeoutInterval: timeout
                    , prepare: { _ in
                        self.stop()
                        prepare?()
                        self.go(to: address)
                        self.read(platform)
                }
                    , progress: { _, progress in
                        update(progress)
                        self.continue()
                }
                    , responseEvaluator: responseEvaluator
                    , result: $0)
                    .start()
            }
            self.stop()
            return data
        }
    }
    
    fileprivate func flushBuffer<Platform: Gibby.Platform>(for platform: Platform.Type, byteCount: Int = 64, startingAt address: Platform.AddressSpace = 0) -> Result<Data, Error> {
        return self.read(platform: platform, byteCount: byteCount, startingAt: address)
    }
    
    @discardableResult
    fileprivate func `continue`() -> Bool {
        return send("1".bytes())
    }
    
    @discardableResult
    fileprivate func stop(timeout: UInt32 = 0) -> Bool {
        return send("0".bytes(), timeout: timeout)
    }
    
    @discardableResult
    fileprivate func read<Platform: Gibby.Platform>(_ platform: Platform.Type) -> Bool {
        switch platform {
        case is GameboyClassic.Type: return send("R".bytes())
        case is GameboyAdvance.Type: return send("r".bytes())
        default: return false
        }
    }
    
    @discardableResult
    fileprivate func go<AddressSpace>(to address: AddressSpace, timeout: UInt32 = 250) -> Bool where AddressSpace: FixedWidthInteger {
        return send("A", number: address, timeout: timeout)
    }
    
    fileprivate func verify<Platform: Gibby.Platform>(platform: Platform.Type) -> Result<Platform.Type, Error> {
        switch platform {
        case is GameboyClassic.Type: return self.set(voltage: .high).flatMap { _ in .success(platform) }
        case is GameboyAdvance.Type: return self.set(voltage: .low).flatMap { _ in .success(platform) }
        default: return .failure(CartridgeControllerError.platformNotSupported(platform))
        }
    }
}

//MARK: - insideGadgetsController (Platform: GameboyClassic) -
extension insideGadgetsController {
    @discardableResult
    private func set<Number>(bank: Number, at address: Number, timeout: UInt32 = 250) -> Bool where Number: FixedWidthInteger {
        return ( send("B", number: address, radix: 16, timeout: timeout)
            &&   send("B", number:    bank, radix: 10, timeout: timeout))
    }
    
    @discardableResult
    private func toggleRAM(on enabled: Bool, timeout: UInt32 = 250) -> Bool {
        return set(bank: enabled ? 0x0A : 0x00, at: 0, timeout: timeout)
    }
    
    @discardableResult
    fileprivate func mbc2(fix header: GameboyClassic.Header) -> Bool {
        switch header.configuration {
        case .two:
            return (
                self.go(to: 0x0)
                    && self.read(GameboyClassic.self)
                    && self.stop()
            )
        default:
            return false
        }
    }
    
    @discardableResult
    fileprivate func send(saveData data: Data) -> Bool {
        return send("W".data(using: .ascii)! + data)
    }
}

//MARK: - insideGadgetsController (Write/Erase) -
extension insideGadgetsController {
    @discardableResult
    private func flash(byte: Int, at address: Int, timeout: UInt32 = 250) -> Bool {
        return ( send("F", number: address)
            && send("", number: byte )
        )
    }
    
    @discardableResult
    private func romMode() -> Bool {
        return send("G".bytes())
    }
    
    @discardableResult
    private func pin(mode: String) -> Bool {
        return (
            send("P".bytes())
                && send(mode.bytes())
        )
    }
    
    fileprivate func sendAndWait(_ block: @escaping () -> (), responseEvaluator: @escaping ORSSerialPacketEvaluator = { _ in true }) -> Result<Data, Error> {
        precondition(Thread.current != .main)
        return Result { try await
            {
                self.request(totalBytes: 1
                    , packetSize: 1
                    , prepare: { _ in block() }
                    , progress: { _, _ in }
                    , responseEvaluator: responseEvaluator
                    , result: $0)
                    .start()
            }
        }
    }
    
    fileprivate func sendEraseFlashProgramResult<FlashCartridge: CartKit.FlashCartridge>(_ chipset: FlashCartridge.Type) -> Result<(), Error> {
        switch chipset {
        case is AM29F016B.Type:
            return self
                .sendAndWait({
                    self.romMode()
                    self.pin(mode: "W")
                    self.flash(byte: 0xAA, at: 0x555)
                })
                .flatMap { _ in self.sendAndWait({ self.flash(byte: 0x55, at: 0x2AA) }) }
                .flatMap { _ in self.sendAndWait({ self.flash(byte: 0x80, at: 0x555) }) }
                .flatMap { _ in self.sendAndWait({ self.flash(byte: 0xAA, at: 0x555) }) }
                .flatMap { _ in self.sendAndWait({ self.flash(byte: 0x55, at: 0x2AA) }) }
                .flatMap { _ in self.sendAndWait({ self.flash(byte: 0x10, at: 0x555) }) }
                .map { _ in () }
        default:
            return .failure(CartridgeFlashError.unsupportedChipset(chipset))
        }
    }
    
    fileprivate func resetFlashModeResult<FlashCartridge: CartKit.FlashCartridge>(_ chipset: FlashCartridge.Type) -> Result<(), Error> {
        switch chipset {
        case is AM29F016B.Type:
            return self
                .sendAndWait({ self.flash(byte: 0xF0, at: 0x00) }) { $0!.starts(with: [0x31]) }
                .map { _ in () }
        default:
            return .failure(CartridgeFlashError.unsupportedChipset(chipset))
        }
    }
    
    fileprivate func sendWriteFlashProgram<FlashCartridge: CartKit.FlashCartridge>(for chipset: FlashCartridge.Type) -> Result<(), Error> {
        switch chipset {
        case is AM29F016B.Type:
            let hexCodes = [ // '555'
                (0x555, 0xAA)
                ,  (0x2AA, 0x55)
                ,  (0x555, 0xA0)
            ]
            return self
                .sendAndWait({
                    self.romMode()
                    self.pin(mode: "W")
                    self.send("E".bytes())
                    self.send("", number: hexCodes[0].0)
                })
                .flatMap { _ in self.sendAndWait({ self.send("", number: hexCodes[0].1) }, responseEvaluator: { $0!.starts(with: [0x31]) }) }
                .flatMap { _ in self.sendAndWait({ self.send("", number: hexCodes[1].0) }, responseEvaluator: { $0!.starts(with: [0x31]) }) }
                .flatMap { _ in self.sendAndWait({ self.send("", number: hexCodes[1].1) }, responseEvaluator: { $0!.starts(with: [0x31]) }) }
                .flatMap { _ in self.sendAndWait({ self.send("", number: hexCodes[2].0) }, responseEvaluator: { $0!.starts(with: [0x31]) }) }
                .flatMap { _ in self.sendAndWait({ self.send("", number: hexCodes[2].1) }, responseEvaluator: { $0!.starts(with: [0x31]) }) }
                .map { _ in () }
        default:
            return .failure(CartridgeFlashError.unsupportedChipset(chipset))
        }
    }
    
}

//MARK: - insideGadgetsController (Flash Chipset) -
extension insideGadgetsController {
    fileprivate func flash(_ flashCartridge: AM29F016B, progress: Progress) -> Result<(), Error> {
        return Result {
            let header = flashCartridge.header
            for bank in 0..<header.romBanks {
                let startIndex = bank * header.romBankSize
                let endIndex   = startIndex.advanced(by: header.romBankSize)
                //--------------------------------------------------------------
                let slice  = flashCartridge[startIndex..<endIndex]
                let romBankSize = Int64(slice.count)
                //--------------------------------------------------------------
                progress.becomeCurrent(withPendingUnitCount: romBankSize)
                //--------------------------------------------------------------
                _ = try await {
                    self.request(totalBytes: (slice.count / 64)
                        , packetSize: 1
                        , prepare: { _ in
                            self.stop()
                            self.set(bank: bank, at: 0x2100)
                            self.go(to: bank > 0 ? 0x4000 : 0x0000)
                            
                            let startAddress = slice.startIndex
                            let bytesInRange = startAddress..<(startAddress + 64)
                            let bytesToWrite = "T".data(using: .ascii)! + Data(slice[bytesInRange])
                            
                            self.send(bytesToWrite)
                    }
                        , progress: { _, progress in
                            let startAddress = Int((progress.completedUnitCount * 64).advanced(by: Int(slice.startIndex)))
                            let bytesInRange = startAddress..<(startAddress + 64)
                            let bytesToWrite = "T".data(using: .ascii)! + Data(slice[bytesInRange])
                            self.send(bytesToWrite)
                    }
                        , responseEvaluator: { _ in true }
                        , result: $0)
                        .start()
                }
                //--------------------------------------------------------------
                progress.resignCurrent()
            }
        }
    }
}
