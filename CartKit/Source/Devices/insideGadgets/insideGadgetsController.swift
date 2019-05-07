import ORSSerial
import Gibby

public class insideGadgetsController<Platform: Gibby.Platform>: ThreadSafeSerialPortController {
    /**
     */
    public override init(matching portProfile: ORSSerialPortManager.PortProfile = .GBxCart) throws {
        try super.init(matching: portProfile)
    }
    
    /// The operation queue to submit _requests_ on.
    ///
    /// - warning:
    /// Upon starting requests, the calling thread gets blocked until a response
    /// can materialize. However, `SerialPortRequest` is to receive serial port
    /// delegate callbacks on the main thread, so if the thread that starts the
    /// request is also the main thread **a deadlock is guaranteed to occur**.
    fileprivate let queue = OperationQueue()
    
    /**
     Opens the serial port.
     
     In addition to being opened, the serial port is explicitly configured as
     if it were device manufactured by insideGadgets.com before returning.
     
     - Returns: An open serial port.
     */
    public override func open() -> ORSSerialPort {
        return super.open().configuredAsGBxCart()
    }
}

extension insideGadgetsController: CartridgeReader {
    @discardableResult
    private func `continue`() -> Bool {
        return send("1".bytes())
    }
    
    @discardableResult
    private func stop(timeout: UInt32 = 0) -> Bool {
        return send("0".bytes(), timeout: timeout)
    }
    
    @discardableResult
    private func read() -> Bool {
        switch Platform.self {
        case is GameboyClassic.Type: return send("R".bytes())
        case is GameboyAdvance.Type: return send("r".bytes())
        default: return false
        }
    }
    
    @discardableResult
    private func go(to address: Platform.AddressSpace, timeout: UInt32 = 250) -> Bool {
        return send("A", number: address, timeout: timeout)
    }
    
    /**
     */
    private func headerResult() -> Result<Platform.Header, Error> {
        return self.read(byteCount: Platform.headerRange.count
            , startingAt: Platform.headerRange.lowerBound
            , prepare: {
                switch Platform.self {
                case is GameboyClassic.Type: (self as! insideGadgetsController<GameboyClassic>).toggleRAM(on: false)
                case is GameboyAdvance.Type: ()
                default: (/* TODO: INVALID PLATFORM ERROR */)
                }
            })
            .flatMap { data in
                let header = Platform.Header(bytes: data)
                guard header.isLogoValid else {
                    return .failure(CartridgeReaderError<Platform>.invalidHeader)
                }
                return .success(header)
            }
    }
    
    private func cartridgeResult(_ update: @escaping ProgressCallback) -> Result<Platform.Cartridge, Error> {
        return self
            .headerResult()
            .flatMap { header in
                var progress: Progress!
                //--------------------------------------------------------------
                switch Platform.self {
                case is GameboyClassic.Type: progress = Progress(totalUnitCount: Int64((header as! GameboyClassic.Header).romSize))
                case is GameboyAdvance.Type: progress = Progress(totalUnitCount: Int64((self as! insideGadgetsController<GameboyAdvance>).romSize()))
                default:
                    return .failure(CartridgeReaderError.platformNotSupported(Platform.self))
                }
                let observer = progress.observe(\.fractionCompleted, options: [.new]) { _, change in
                    DispatchQueue.main.sync {
                        update(change.newValue ?? 0)
                    }
                }
                //--------------------------------------------------------------
                defer { observer.invalidate() }
                //--------------------------------------------------------------
                switch Platform.self {
                case is GameboyClassic.Type:
                    return (self as! insideGadgetsController<GameboyClassic>)
                        .romDataResult(updating: progress, header: header as! GameboyClassic.Header)
                        .map { .init(bytes: $0) }
                default:
                    return .failure(CartridgeReaderError.platformNotSupported(Platform.self))
                }
        }
    }
    
    private func backupResult(_ update: @escaping ProgressCallback) -> Result<Data, Error> {
        return self
            .headerResult()
            .flatMap { header in
                var progress: Progress!
                //--------------------------------------------------------------
                switch Platform.self {
                case is GameboyClassic.Type: progress = Progress(totalUnitCount: Int64((header as! GameboyClassic.Header).ramSize))
                case is GameboyAdvance.Type: progress = Progress(totalUnitCount: Int64((self as! insideGadgetsController<GameboyAdvance>).ramSize()))
                default:
                    return .failure(CartridgeReaderError.platformNotSupported(Platform.self))
                }
                let observer = progress.observe(\.fractionCompleted, options: [.new]) { _, change in
                    DispatchQueue.main.sync {
                        update(change.newValue ?? 0)
                    }
                }
                //--------------------------------------------------------------
                defer { observer.invalidate() }
                //--------------------------------------------------------------
                switch Platform.self {
                case is GameboyClassic.Type:
                    return (self as! insideGadgetsController<GameboyClassic>)
                        .ramDataResult(updating: progress, header: header as! GameboyClassic.Header)
                default:
                    return .failure(CartridgeReaderError.platformNotSupported(Platform.self))
                }
        }
    }

    private func restoreResult(_ data: Data, _ update: @escaping ProgressCallback) -> Result<(), Error> {
        return self
            .headerResult()
            .flatMap { header in
                var progress: Progress!
                //--------------------------------------------------------------
                switch Platform.self {
                case is GameboyClassic.Type: progress = Progress(totalUnitCount: Int64((header as! GameboyClassic.Header).ramSize))
                case is GameboyAdvance.Type: progress = Progress(totalUnitCount: Int64((self as! insideGadgetsController<GameboyAdvance>).ramSize()))
                default:
                    return .failure(CartridgeReaderError.platformNotSupported(Platform.self))
                }
                let observer = progress.observe(\.fractionCompleted, options: [.new]) { _, change in
                    DispatchQueue.main.sync {
                        update(change.newValue ?? 0)
                    }
                }
                //--------------------------------------------------------------
                defer { observer.invalidate() }
                //--------------------------------------------------------------
                switch Platform.self {
                case is GameboyClassic.Type:
                    return (self as! insideGadgetsController<GameboyClassic>)
                        .write(saveData: data, updating: progress, header: header as! GameboyClassic.Header)
                default:
                    return .failure(CartridgeReaderError.platformNotSupported(Platform.self))
                }
        }
    }
    
    private func deleteResult(_ update: @escaping ProgressCallback) -> Result<(), Error> {
        return self
            .headerResult()
            .flatMap {
                switch Platform.self {
                case is GameboyClassic.Type: return .success(Data(count: ($0 as! GameboyClassic.Header).ramSize))
                case is GameboyAdvance.Type: return .success(Data(count: (self as! insideGadgetsController<GameboyAdvance>).ramSize()))
                default: return .failure(CartridgeReaderError.platformNotSupported(Platform.self))
                }
            }
            .flatMap { self.restoreResult($0, update) }
    }
    
    public func read<Number>(byteCount: Number, startingAt address: Platform.AddressSpace, timeout: TimeInterval = -1.0, prepare: (() -> ())? = nil, progress update: @escaping (Progress) -> () = { _ in }, responseEvaluator: @escaping ORSSerialPacketEvaluator = { _ in true }) -> Result<Data, Error> where Number: FixedWidthInteger {
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
                        self.read()
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
    
    public func sendAndWait(_ block: @escaping () -> (), responseEvaluator: @escaping ORSSerialPacketEvaluator = { _ in true }) -> Result<Data, Error> {
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
    
    public func scanHeader(_ result: @escaping (Result<Platform.Header, Error>) -> ()) {
        self.queue.addOperation(BlockOperation {
            result(self.headerResult())
        })
    }
    
    public func readCartridge(progress: @escaping ProgressCallback, _ result: @escaping (Result<Platform.Cartridge, Error>) -> ()) {
        self.queue.addOperation(BlockOperation {
            result(self.cartridgeResult(progress))
        })
    }
    
    public func backupSave(progress: @escaping ProgressCallback, _ result: @escaping (Result<Data, Error>) -> ()) {
        self.queue.addOperation(BlockOperation {
            result(self.backupResult(progress))
        })
    }
    
    public func restoreSave(data: Data, progress: @escaping ProgressCallback, _ result: @escaping (Result<(), Error>) -> ()) {
        self.queue.addOperation(BlockOperation {
            result(self.restoreResult(data, progress))
        })
    }
    
    public func deleteSave(progress: @escaping ProgressCallback, _ result: @escaping (Result<(), Error>) -> ()) {
        self.queue.addOperation(BlockOperation {
            result(self.deleteResult(progress))
        })
    }
}

extension insideGadgetsController where Platform == GameboyAdvance {
    @discardableResult
    fileprivate func romSize() -> Int {
        return 0
    }
    
    @discardableResult
    fileprivate func ramSize() -> Int {
        return 0
    }
}

extension insideGadgetsController where Platform == GameboyClassic {
    @discardableResult
    fileprivate func toggleRAM(on enabled: Bool, timeout: UInt32 = 250) -> Bool {
        return set(bank: enabled ? 0x0A : 0x00, at: 0, timeout: timeout)
    }
    
    @discardableResult
    fileprivate func set<Number>(bank: Number, at address: Platform.AddressSpace, timeout: UInt32 = 250) -> Bool where Number : FixedWidthInteger {
        return ( send("B", number: address, radix: 16, timeout: timeout)
            &&   send("B", number:    bank, radix: 10, timeout: timeout))
    }
    
    @discardableResult
    private func mbc2(fix header: Platform.Header) -> Bool {
        switch header.configuration {
        case .two:
            return (
                self.go(to: 0x0)
                    && self.read()
                    && self.stop()
            )
        default:
            return false
        }
    }
    
    @discardableResult
    private func send(saveData data: Data) -> Bool {
        return send("W".data(using: .ascii)! + data)
    }
    
    fileprivate func romDataResult(updating progress: Progress, header: Platform.Header) -> Result<Data, Error> {
        return Result {
            var romData = Data()
            for bank in 0..<header.romBanks {
                progress.becomeCurrent(withPendingUnitCount: Int64(header.romBankSize))
                //--------------------------------------------------------------
                let bankData = try self.read(byteCount: header.romBankSize
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
    
    fileprivate func ramDataResult(updating progress: Progress, header: Platform.Header) -> Result<Data, Error> {
        return Result {
            let ramBankSize = Int64(header.ramBankSize)
            var backupData = Data()
            for bank in 0..<header.ramBanks {
                progress.becomeCurrent(withPendingUnitCount: ramBankSize)
                //--------------------------------------------------------------
                let bankData = try self.read(byteCount: ramBankSize
                    , startingAt: 0xA000
                    , prepare: {
                        self.mbc2(fix: header)
                        //--------------------------------------------------
                        // SET: the 'RAM' mode (MBC1-ONLY)
                        //--------------------------------------------------
                        if case .one = header.configuration {
                            self.set(bank: 1, at: 0x6000)
                        }
                        //--------------------------------------------------
                        self.toggleRAM(on: true)
                        self.set(bank: bank, at: 0x4000)
                }).get()
                //--------------------------------------------------------------
                backupData.append(bankData)
                //--------------------------------------------------------------
                progress.resignCurrent()
            }
            return backupData
        }
    }
    
    fileprivate func write(saveData data: Data, updating progress: Progress, header: Platform.Header) -> Result<(), Error> {
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

extension insideGadgetsController: CartridgeEraser {
    @discardableResult
    private func flash<Number>(byte: Number, at address: Platform.AddressSpace, timeout: UInt32 = 250) -> Bool where Number : FixedWidthInteger {
        return ( send("F", number: address)
            &&   send("", number: byte)
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
    
    private func resetFlashModeResult<FlashCartridge: CartKit.FlashCartridge>(_ chipset: FlashCartridge.Type) -> Result<(), Error> {
        switch chipset {
        case is AM29F016B.Type:
            return self
                .sendAndWait({ self.flash(byte: 0xF0, at: 0x00) }) { $0!.starts(with: [0x31]) }
                .map { _ in () }
        default:
            return .failure(CartridgeEraserError.unsupportedChipset(chipset))
        }
    }
    
    private func sendEraseFlashProgramResult<FlashCartridge: CartKit.FlashCartridge>(_ chipset: FlashCartridge.Type) -> Result<(), Error> {
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
            return .failure(CartridgeEraserError.unsupportedChipset(chipset))
        }
    }
    
    private func flushBufferResult(_ byteCount: Int = 64, startingAt address: Platform.AddressSpace = 0) -> Result<Data, Error> {
        return self.read(byteCount: byteCount, startingAt: address)
    }

    public func erase<FlashCartridge: CartKit.FlashCartridge>(_ chipset: FlashCartridge.Type, _ result: @escaping (Result<(), Error>) -> ()) {
        return result(.failure(CartridgeEraserError.unsupportedChipset(chipset)))
    }
    
    public func erase(_ chipset: AM29F016B.Type, _ result: @escaping (Result<(), Error>) -> ()) {
        self.queue.addOperation(BlockOperation {
            result(self
                .resetFlashModeResult(chipset)
                .flatMap { self.flushBufferResult() }
                .flatMap { _ in self.sendEraseFlashProgramResult(chipset) }
                .flatMap { _ in
                    self.read(byteCount: 1
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
            )
        })
    }
    
    private func determineFlashCartResult(bitFlipped: Bool = true) -> Result<String, Error> {
        return self
            .sendAndWait({ self.flash(byte: bitFlipped ? 0xAA : 0xA9, at: 0xAAA) })
            .flatMap { _ in self.sendAndWait({ self.flash(byte: 0x55, at: 0x555) }) }
            .flatMap { _ in self.sendAndWait({ self.flash(byte: 0x90, at: 0xAAA) }) }
            .flatMap { _ in self.flushBufferResult().map { $0.hexString() } }
            .flatMap { description in
                self.sendAndWait({ self.flash(byte: 0xF0, at: 0x00) }).map { _ in description }
            }
    }
    
    public func flashCartDescription(_ result: @escaping (Result<String, Error>) -> ()) {
        self.queue.addOperation(BlockOperation {
            result(self.determineFlashCartResult())
        })
    }
}
