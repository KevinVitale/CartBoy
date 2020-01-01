import Foundation
import Gibby
import ORSSerial

public struct GBxCart: DeviceProfile {
    typealias SerialDevice = ThreadSafeSerialPortController
    
    public static let portProfile: ORSSerialPortManager.PortProfile = .usb( vendorID: 6790,
                                                                           productID: 29987 )
    
    public static func configure(serialPort: ORSSerialPort) -> ORSSerialPort {
        serialPort.configuredAsGBxCart()
    }
    
    private static func read<Platform: Gibby.Platform, Number> (
        fromSerialDevice serialDevice: SerialDevice,
                             platform: Platform.Type,
                            byteCount: Number,
                   startingAt address: Platform.AddressSpace,
                              timeout: TimeInterval = -1.0,
                              prepare: (() -> ())? = nil,
                      progress update: @escaping (Progress) -> () = { _ in },
                    responseEvaluator: @escaping ORSSerialPacketEvaluator = { _ in true }) -> Result<Data, Error> where Number: FixedWidthInteger
    {
        Result {
            let data = try await {
                serialDevice.request(totalBytes: byteCount,
                                     packetSize: 64,
                                timeoutInterval: timeout,
                                        prepare: ({ _ in
                                            self.stopReading(from: serialDevice)
                                            prepare?()
                                            self.seek(serialDevice, to: address)
                                            self.startReading(from: serialDevice, platformType: platform)
                                        }),
                                       progress: ({ _, progress in
                                            update(progress)
                                            self.continue(serialDevice)
                                       }),
                              responseEvaluator: responseEvaluator,
                                         result: $0)
                    .start()
            }
            self.stopReading(from: serialDevice)
            return data
        }
    }
    
    @discardableResult
    private static func `continue`(_ serialDevice: SerialDevice) -> Bool {
        serialDevice.send("1".bytes())
    }
    
    @discardableResult
    private static func stopReading(from serialDevice: SerialDevice, timeout: UInt32 = 0) -> Bool {
        serialDevice.send("0".bytes(), timeout: timeout)
    }
    
    @discardableResult
    private static func seek<AddressSpace>(_ serialDevice: SerialDevice,
                                               to address: AddressSpace,
                                                  timeout: UInt32 = 250) -> Bool where AddressSpace: FixedWidthInteger
    {
        serialDevice.send("A", number: address, timeout: timeout)
    }
    
    @discardableResult
    private static func startReading<Platform: Gibby.Platform>(from serialDevice: SerialDevice,
                                                           platformType platform: Platform.Type) -> Bool
    {
        switch platform {
        case is GameboyClassic.Type: return serialDevice.send("R".bytes())
        case is GameboyAdvance.Type: return serialDevice.send("r".bytes())
        default: return false
        }
    }
    
    
    @discardableResult
    private static func write(to serialDevice: SerialDevice,
                                saveData data: Data) -> Bool
    {
        serialDevice.send("W".data(using: .ascii)! + data)
    }
    
    @discardableResult
    private static func setBank<Number>(_ serialDevice: SerialDevice,
                                                  bank: Number,
                                            at address: Number,
                                               timeout: UInt32 = 250) -> Bool where Number: FixedWidthInteger
    {
        return ( serialDevice.send("B", number: address, radix: 16, timeout: timeout)
            &&   serialDevice.send("B", number:    bank, radix: 10, timeout: timeout))
    }
    
    @discardableResult
    private static func toggleRAM(_ serialDevice: SerialDevice,
                                         enabled: Bool,
                                         timeout: UInt32 = 250) -> Bool
    {
        setBank(serialDevice, bank: enabled ? 0x0A : 0x00, at: 0, timeout: timeout)
    }
    
    @discardableResult
    private static func mbc2(_ serialDevice: SerialDevice,
                                 fix header: GameboyClassic.Header) -> Bool
    {
        switch header.configuration {
        case .two:
            return (
                self.seek(serialDevice, to: 0x0)
                    && self.startReading(from: serialDevice, platformType: GameboyClassic.self)
                    && self.stopReading(from: serialDevice)
            )
        default:
            return false
        }
    }
    
    private static let TerminatingResponse: ((Data?) -> Bool) = { $0!.starts(with: [0x31]) }

    private static func waitFor( _ serialDevice: SerialDevice,
                                 atMost timeout: TimeInterval = -1,
                     toReturn responseEvaluator: @escaping ORSSerialPacketEvaluator = TerminatingResponse,
                              fromRequest block: @escaping () -> () ) -> Result<Data, Error>
    {
        Result { try await {
            serialDevice.request(totalBytes: 1
                , packetSize: 1
                , timeoutInterval: timeout
                , prepare: { _ in block() }
                , progress: { _, _ in }
                , responseEvaluator: responseEvaluator
                , result: $0)
                .start()
            }
        }
    }
    
    private static func flushBuffer<Platform: Gibby.Platform>(_ serialDevice: SerialDevice,
                                                                for platform: Platform.Type,
                                                                   byteCount: Int = 64,
                                                          startingAt address: Platform.AddressSpace = 0) -> Result<Data, Error>
    {
        self.read(fromSerialDevice: serialDevice,
                          platform: platform,
                         byteCount: byteCount,
                        startingAt: address)
    }

    @discardableResult
    private static func flash(_ serialDevice: SerialDevice,
                                 byte: Int,
                           at address: Int,
                              timeout: UInt32 = 250) -> Bool
    {
        return ( serialDevice.send("F", number: address)
              && serialDevice.send("", number: byte ))
    }
}

extension ORSSerialPort {
    @discardableResult
    final func configuredAsGBxCart() -> ORSSerialPort {
        self.allowsNonStandardBaudRates = true
        self.baudRate = 1000000
        self.dtr = true
        self.rts = true
        self.numberOfDataBits = 8
        self.numberOfStopBits = 1
        self.parity = .none
        return self
    }
}

fileprivate extension GBxCart {
    static func version(_ serialDevice: SerialDevice) -> Result<Data,Error> {
        Result {
            try await {
                serialDevice.request(totalBytes: 1,
                                     packetSize: 1,
                                timeoutInterval: 1.5,
                                        prepare: { _ in
                                            self.stopReading(from: serialDevice)
                                            serialDevice.send("h\0".bytes(), timeout: 500) },
                                       progress: { _, _ in },
                              responseEvaluator: { _ in true },
                                         result: $0).start()
            }
        }
    }
    
    static func voltage<Platform: Gibby.Platform>(forPlatform platform: Platform.Type) -> Result<Voltage,Error> {
        Result<Voltage,Error>(catching: {
            switch platform {
            case is GameboyClassic.Type: return .high
            case is GameboyAdvance.Type: return .low
            default: throw SerialDeviceError.platformNotSupported(platform)
            }
        })
    }

    static func voltage(_ serialDevice: SerialDevice) -> Result<Voltage,Error> {
        Result {
            let data = try await {
                serialDevice.request(totalBytes: 1,
                                     packetSize: 1,
                                timeoutInterval: 1.5,
                                        prepare: { _ in
                                            self.stopReading(from: serialDevice)
                                            serialDevice.send("C\0".bytes(), timeout: 500) },
                                       progress: { _, _ in },
                              responseEvaluator: { _ in true },
                                         result: $0)
                    .start()
            }
            guard let voltage = data.compactMap(Voltage.init).first else {
                throw VoltageError.invalidVoltage
            }
            return voltage
        }
    }
    
    static func serialDevice(_ serialDevice: SerialDevice, setVoltage voltage: Voltage) -> Result<(),Error> {
        version(serialDevice).flatMap({ version in
            let pcbVersion = Int(version.hexString()) ?? .min
            // -----------------------------------------------------------------
            guard pcbVersion > 2 else {
                return .success(())
            }
            // -----------------------------------------------------------------
            // For versions 3+, setting the voltage can only be done via
            // software.
            //
            // This sets the voltage by sending the command and letting the
            // operation intentionally timeout (after 500ms).
            // -----------------------------------------------------------------
            let _ = try? await {
                serialDevice.request(totalBytes: 1,
                                     packetSize: 1,
                                timeoutInterval: 0.5,
                                        prepare: ({ _ in
                                            let byteCmd = voltage == .low ? "3" : "5"
                                            let timeout = UInt32(500)
                                            serialDevice.send("\(byteCmd)\0".bytes(), timeout: timeout)
                                        }),
                                       progress: { _, _ in },
                              responseEvaluator: { _ in true },
                                         result: $0)
                    .start()
            }
            return .success(())
        })
    }

    static func serialDevice<Platform: Gibby.Platform>(_ serialDevice: SerialDevice, readHeaderFor platform: Platform.Type) -> Result<Platform.Header,Error> {
        self.voltage(forPlatform: platform)
            .flatMap({ self.serialDevice(serialDevice, setVoltage: $0) })
            .flatMap({
                self.read(fromSerialDevice: serialDevice,
                                  platform: platform,
                                 byteCount: Platform.headerRange.count,
                                startingAt: Platform.headerRange.lowerBound,
                                   prepare: ({
                                       if platform is GameboyClassic.Type {
                                           self.toggleRAM(serialDevice, enabled: false)
                                       }
                                   }))
            })
            .map(Platform.Header.init)
            .flatMap({ header in
                guard header.isLogoValid else {
                    return .failure(SerialDeviceError<Platform>.invalidHeader)
                }
                return .success(header)
            })
    }
    
    static func serialDevice(_ serialDevice: SerialDevice, readAdvanceCartridge update: ((Double) -> ())?) -> Result<GameboyAdvance.Cartridge,Error> {
        .failure(SerialDeviceError.platformNotSupported(GameboyAdvance.self))
    }
    
    static func serialDevice(_ serialDevice: SerialDevice, readClassicCartridge update: ((Double) -> ())?) -> Result<GameboyClassic.Cartridge,Error> {
        self.serialDevice(serialDevice, readHeaderFor: GameboyClassic.self)
            .map({ ($0, Progress(totalUnitCount: Int64($0.romSize))) })
            .flatMap({ (header, progress) in
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
                    var romData = Data()
                    for bank in 0..<header.romBanks {
                        progress.becomeCurrent(withPendingUnitCount: Int64(header.romBankSize))
                        //------------------------------------------------------
                        let bankData = try self.read(
                            fromSerialDevice: serialDevice,
                                    platform: GameboyClassic.self,
                                   byteCount: header.romBankSize,
                                  startingAt: bank > 0 ? 0x4000 : 0x0000,
                                     prepare: ({
                                        self.mbc2(serialDevice, fix: header)
                                        //--------------------------------------
                                        guard bank > 0 else { return }
                                        //--------------------------------------
                                        if case .one = header.configuration {
                                            self.setBank(serialDevice, bank:           0, at: 0x6000)
                                            self.setBank(serialDevice, bank:   bank >> 5, at: 0x4000)
                                            self.setBank(serialDevice, bank: bank & 0x1F, at: 0x2000)
                                        }
                                        else {
                                            self.setBank(serialDevice, bank: bank, at: 0x2100)
                                            if bank > 0x100 {
                                                self.setBank(serialDevice, bank: 1, at: 0x3000)
                                            }
                                        }
                                     })
                        ).get()
                        //------------------------------------------------------
                        romData.append(bankData)
                        //------------------------------------------------------
                        progress.resignCurrent()
                    }
                    return romData
                }
            })
            .map { .init(bytes: $0) }
    }
    
    static func serialDevice(_ serialDevice: SerialDevice, readSaveFromAdvanceCartridge update: ((Double) -> ())?) -> Result<Data,Error> {
        .failure(SerialDeviceError.platformNotSupported(GameboyAdvance.self))
    }
    
    static func serialDevice(_ serialDevice: SerialDevice, readSaveFromClassicCartridge update: ((Double) -> ())?) -> Result<Data,Error> {
        self.serialDevice(serialDevice, readHeaderFor: GameboyClassic.self)
            .map { ($0, Progress(totalUnitCount: Int64($0.ramSize))) }
            .flatMap { (header, progress) in
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
                    let ramBankSize = Int64(header.ramBankSize)
                    var backupData = Data()
                    for bank in 0..<header.ramBanks {
                        //------------------------------------------------------
                        progress.becomeCurrent(withPendingUnitCount: ramBankSize)
                        //------------------------------------------------------
                        let bankData = try self.read(
                            fromSerialDevice: serialDevice,
                                    platform: GameboyClassic.self,
                                   byteCount: ramBankSize,
                                  startingAt: 0xA000,
                                     prepare: ({
                                        self.mbc2(serialDevice, fix: header)
                                        //--------------------------------------
                                        // SET: the 'RAM' mode (MBC1-ONLY)
                                        //--------------------------------------
                                        if case .one = header.configuration {
                                            self.setBank(serialDevice, bank: 1, at: 0x6000)
                                        }
                                        //--------------------------------------
                                        self.toggleRAM(serialDevice, enabled: true)
                                        self.setBank(serialDevice, bank: bank, at: 0x4000)
                                     })
                        ).get()
                        //------------------------------------------------------
                        backupData.append(bankData)
                        //------------------------------------------------------
                        progress.resignCurrent()
                    }
                    return backupData
                }
        }
    }
    
    static func serialDevice(_ serialDevice: SerialDevice, writeSaveToAdvanceCartridge data: Data, update: ((Double) -> ())?) -> Result<(),Error> {
        .failure(SerialDeviceError.platformNotSupported(GameboyAdvance.self))
    }
    
    static func serialDevice(_ serialDevice: SerialDevice, writeSaveToClassicCartridge data: Data, update: ((Double) -> ())?) -> Result<(),Error> {
        self.serialDevice(serialDevice, readHeaderFor: GameboyClassic.self)
            .map { ($0, Progress(totalUnitCount: Int64($0.ramSize))) }
            .flatMap { (header, progress) in
                var observer: NSKeyValueObservation?
                if let update = update {
                    observer = progress.observe(\.fractionCompleted,
                                                    options: [.new]) { _, change in
                        DispatchQueue.main.async {
                            update(change.newValue ?? 0)
                        }
                    }
                }
                defer { observer?.invalidate() }
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
                            serialDevice.request(totalBytes: ramBankSize / 64,
                                                 packetSize: 1,
                                                    prepare: ({ _ in
                                                        if bank == 0 { self.toggleRAM(serialDevice, enabled: true) }
                                                        //----------------------
                                                        self.stopReading(from: serialDevice)
                                                        self.mbc2(serialDevice, fix: header)
                                                        //----------------------
                                                        // SET: the 'RAM' mode (MBC1-ONLY)
                                                        //----------------------
                                                        if case .one = header.configuration {
                                                            self.setBank(serialDevice, bank: 1, at: 0x6000)
                                                        }
                                                        //----------------------
                                                        self.setBank(serialDevice, bank: bank, at: 0x4000)
                                                        self.seek(serialDevice, to: 0xA000)
                                                        self.write(to: serialDevice, saveData: slice[slice.startIndex..<slice.startIndex.advanced(by: 64)])
                                                    }),
                                                    progress: ({ _, progress in
                                                        let startAddress = Int(progress.completedUnitCount * 64).advanced(by: slice.startIndex)
                                                        let rangeOfBytes = startAddress..<Int(startAddress + 64)
                                                        self.write(to: serialDevice, saveData: slice[rangeOfBytes])
                                                    }),
                                                    responseEvaluator: ({ _ in true }),
                                                    result: $0)
                                .start()
                        }
                        //--------------------------------------------------------------
                        progress.resignCurrent()
                    }
                }
        }
    }
    
    static func serialDevice(_ serialDevice: SerialDevice, deleteSaveOnAdvanceCartridge update: ((Double) -> ())?) -> Result<(),Error> {
        .failure(SerialDeviceError.platformNotSupported(GameboyAdvance.self))
    }
    
    static func serialDevice(_ serialDevice: SerialDevice, deleteSaveOnClassicCartridge update: ((Double) -> ())?) -> Result<(),Error> {
        self.serialDevice(serialDevice, readHeaderFor: GameboyClassic.self)
            .flatMap({ header in
                self.serialDevice(serialDevice, writeSaveToClassicCartridge: Data(count: header.ramSize), update: update)
            })
    }
    
    static func serialDevice<FlashCartridge: CartKit.FlashCartridge>(_ serialDevice: SerialDevice, erase chipset: FlashCartridge.Type) -> Result<(),Error> {
        switch chipset {
        case is AM29F016B.Type:
            return self.eraseAM29F016B(serialDevice)
        default:
            return .failure(CartridgeFlashError.unsupportedChipset(chipset))
        }
    }
    
    
    static func flashAM29F016B(_ serialDevice: SerialDevice,
                               flashCartridge: AM29F016B,
                              progress update: ((Double) -> ())?) -> Result<(),Error>
    {
        self.eraseAM29F016B(serialDevice)
            .flatMap({ self.flushBuffer(serialDevice, for: GameboyClassic.self) })
            .flatMap({ _ in
                let hexCodes = [ // '555'
                    (0x555, 0xAA),
                    (0x2AA, 0x55),
                    (0x555, 0xA0)
                ]
                return self.waitFor(serialDevice) {
                    serialDevice.send("G".bytes())  // romMode
                    serialDevice.send("PW".bytes()) // pinMode
                    serialDevice.send("E".bytes())  // romMode
                    serialDevice.send("", number: hexCodes[0].0)
                }
                .flatMap { _ in self.waitFor(serialDevice) { serialDevice.send("", number: hexCodes[0].1) } }
                .flatMap { _ in self.waitFor(serialDevice) { serialDevice.send("", number: hexCodes[1].0) } }
                .flatMap { _ in self.waitFor(serialDevice) { serialDevice.send("", number: hexCodes[1].1) } }
                .flatMap { _ in self.waitFor(serialDevice) { serialDevice.send("", number: hexCodes[2].0) } }
                .flatMap { _ in self.waitFor(serialDevice) { serialDevice.send("", number: hexCodes[2].1) } }
                .map { _ in () }
            })
            .flatMap({
                let progress = Progress(totalUnitCount: Int64(flashCartridge.count))
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
                    let header = flashCartridge.header
                    for bank in 0..<header.romBanks {
                        let startIndex = bank * header.romBankSize
                        let endIndex   = startIndex.advanced(by: header.romBankSize)
                        //------------------------------------------------------
                        let slice  = flashCartridge[startIndex..<endIndex]
                        let romBankSize = Int64(slice.count)
                        //------------------------------------------------------
                        progress.becomeCurrent(withPendingUnitCount: romBankSize)
                        //------------------------------------------------------
                        _ = try await {
                            serialDevice.request(totalBytes: (slice.count / 64),
                                                 packetSize: 1,
                                                 prepare: { _ in
                                                    self.stopReading(from: serialDevice)
                                                    self.setBank(serialDevice, bank: bank, at: 0x2100)
                                                    self.seek(serialDevice, to: bank > 0 ? 0x4000 : 0x0000)
                                                    
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
    }

    static func eraseAM29F016B(_ serialDevice: SerialDevice) -> Result<(),Error> {
        self.waitFor(serialDevice) {
            self.flash(serialDevice, byte: 0xF0, at: 0x00)
            
        }
        .flatMap({ _ in self.flushBuffer(serialDevice, for: GameboyClassic.self) })
        .flatMap({ _ in
            self.waitFor(serialDevice) {
                serialDevice.send("G".bytes())  // romMode
                serialDevice.send("PW".bytes()) // pinMode
                self.flash(serialDevice, byte: 0xAA, at: 0x555)
            }
        })
        .flatMap({ _ in
            self.waitFor(serialDevice, toReturn: { _ in true}) {
                self.flash(serialDevice, byte: 0x55, at: 0x2AA)
            }
        })
        .flatMap({ _ in
            self.waitFor(serialDevice, toReturn: { _ in true}) {
                self.flash(serialDevice, byte: 0x80, at: 0x555)
            }
        })
        .flatMap({ _ in
            self.waitFor(serialDevice, toReturn: { _ in true}) {
                self.flash(serialDevice, byte: 0xAA, at: 0x555)
            }
        })
        .flatMap({ _ in
            self.waitFor(serialDevice, toReturn: { _ in true}) {
                self.flash(serialDevice, byte: 0x55, at: 0x2AA)
            }
        })
        .flatMap({ _ in
            self.waitFor(serialDevice, toReturn: { _ in true}) {
                self.flash(serialDevice, byte: 0x10, at: 0x555)
            }
        })
        .flatMap({ _ in
            self.read(fromSerialDevice: serialDevice,
                              platform: GameboyClassic.self,
                             byteCount: 1,
                            startingAt: 0x0000,
                               timeout: 30,
                     responseEvaluator: {
                        guard $0!.starts(with: [0xFF]) else {
                            self.continue(serialDevice)
                            return false
                        }
                        return true })
        })
        .flatMap({ _ in
            self.waitFor(serialDevice) {
                self.flash(serialDevice, byte: 0xF0, at: 0x00)
            }
        })
        .map({ _ in })
    }
}

public extension Result where Success == SerialDevice<GBxCart> {
    func version() -> Result<String,Error> {
        resultFrom(GBxCart.version(_:)).map({ $0.hexString() })
    }
    
    func voltage() -> Result<Voltage,Error> {
        resultFrom(GBxCart.voltage(_:))
    }
    
    func setVoltage(_ voltage: Voltage) -> Result<(),Error> {
        resultFrom(GBxCart.serialDevice(_:setVoltage:), voltage)
    }
    
    func header<Platform: Gibby.Platform>(forPlatform platform: Platform.Type) -> Result<Platform.Header,Error> {
        resultFrom(GBxCart.serialDevice(_:readHeaderFor:), platform)
    }
    
    func cartridge<Platform: Gibby.Platform>(forPlatform platform: Platform.Type, progress update: ((Double) -> ())? = nil) -> Result<Platform.Cartridge,Error> {
        if update != nil { dispatchPrecondition(condition: .notOnQueue(.main)) }

        switch platform {
        case is GameboyClassic.Type: return resultFrom(GBxCart.serialDevice(_:readClassicCartridge:), update) as! Result<Platform.Cartridge,Error>
        case is GameboyAdvance.Type: return resultFrom(GBxCart.serialDevice(_:readAdvanceCartridge:), update) as! Result<Platform.Cartridge,Error>
        default: return .failure(SerialDeviceError.platformNotSupported(platform))
        }
    }
    
    func backupSave<Platform: Gibby.Platform>(for platform: Platform.Type, progress update: ((Double) -> ())? = nil) -> Result<Data,Error> {
        if update != nil { dispatchPrecondition(condition: .notOnQueue(.main)) }
        
        switch platform {
        case is GameboyClassic.Type: return resultFrom(GBxCart.serialDevice(_:readSaveFromClassicCartridge:), update)
        case is GameboyAdvance.Type: return resultFrom(GBxCart.serialDevice(_:readSaveFromAdvanceCartridge:), update)
        default: return .failure(SerialDeviceError.platformNotSupported(platform))
        }
    }
    
    func restoreSave<Platform: Gibby.Platform>(for platform: Platform.Type, data: Data, progress update: ((Double) -> ())? = nil) -> Result<(),Error> {
        if update != nil { dispatchPrecondition(condition: .notOnQueue(.main)) }
        
        switch platform {
        case is GameboyClassic.Type: return resultFrom(GBxCart.serialDevice(_:writeSaveToClassicCartridge:update:), data, update)
        case is GameboyAdvance.Type: return resultFrom(GBxCart.serialDevice(_:writeSaveToAdvanceCartridge:update:), data, update)
        default: return .failure(SerialDeviceError.platformNotSupported(platform))
        }
    }
    
    func deleteSave<Platform: Gibby.Platform>(for platform: Platform.Type, progress update: ((Double) -> ())? = nil) -> Result<(),Error> {
        if update != nil { dispatchPrecondition(condition: .notOnQueue(.main)) }
        
        switch platform {
        case is GameboyClassic.Type: return resultFrom(GBxCart.serialDevice(_:deleteSaveOnClassicCartridge:), update)
        case is GameboyAdvance.Type: return resultFrom(GBxCart.serialDevice(_:deleteSaveOnAdvanceCartridge:), update)
        default: return .failure(SerialDeviceError.platformNotSupported(platform))
        }
    }
    
    func erase<FlashCartridge: CartKit.FlashCartridge>(flashCartridge chipset: FlashCartridge.Type) -> Result<(), Error> {
        switch chipset.Platform.self {
        case is GameboyClassic.Type:
            switch chipset {
            case is AM29F016B.Type:
                return resultFrom(GBxCart.eraseAM29F016B(_:))
            default:
                return .failure(CartridgeFlashError.unsupportedChipset(chipset))
            }
        case is GameboyAdvance.Type: fallthrough
        default: return .failure(CartridgeFlashError.unsupportedChipset(chipset))
        }
    }
    
    func write<FlashCartridge: CartKit.FlashCartridge>(flashCartridge: FlashCartridge, progress update: ((Double) -> ())? = nil) -> Result<(), Error> {
        if update != nil { dispatchPrecondition(condition: .notOnQueue(.main)) }
        
        switch FlashCartridge.Platform.self {
        case is GameboyClassic.Type:
            switch flashCartridge {
            case let flashCartridge as AM29F016B:
                return resultFrom(GBxCart.flashAM29F016B(_:flashCartridge:progress:), flashCartridge, update)
            default:
                return .failure(CartridgeFlashError.unsupportedChipset(type(of: flashCartridge)))
            }
        case is GameboyAdvance.Type: fallthrough
        default: return .failure(CartridgeFlashError.unsupportedChipset(type(of: flashCartridge)))
        }
    }
}
