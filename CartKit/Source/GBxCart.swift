import Foundation
import Gibby
import ORSSerial

public struct GBxCart: DeviceProfile {
    typealias SerialDevice = ThreadSafeSerialPortController
    
    public static let portProfile: ORSSerialPortManager.PortProfile = .usb( vendorID: 6790, productID: 29987 )
    
    public static func configure(serialPort: ORSSerialPort) -> ORSSerialPort {
        serialPort.allowsNonStandardBaudRates = true
        serialPort.baudRate = 1000000
        serialPort.dtr = true
        serialPort.rts = true
        serialPort.numberOfDataBits = 8
        serialPort.numberOfStopBits = 1
        serialPort.parity = .none
        return serialPort
    }
}

extension SerialDevice where Device == GBxCart {
    func seek<Address: FixedWidthInteger>(toAddress address: Address) {
        send(.bytes(forCommand: "A", number: address), timeout: 250)
    }
    
    @discardableResult
    func setBank<Number>(
        _ bank     :Number,
        at address :Number,
        timeout    :UInt32 = 250) -> Bool where Number: FixedWidthInteger
    {
        return ( send(.bytes(forCommand: "B", number: address, radix: 16), timeout: timeout)
            &&   send(.bytes(forCommand: "B", number:    bank, radix: 10), timeout: timeout))
    }
    
    func startReading<Platform: Gibby.Platform>(forPlatform platform: Platform.Type) {
        switch platform {
        case is GameboyClassic.Type: send("R".bytes(), timeout: 250)
        case is GameboyAdvance.Type: send("r".bytes(), timeout: 250)
        default: ()
        }
    }
}

public extension Result where Success == SerialDevice<GBxCart>, Failure == Swift.Error {
    /**
     *
     */
    func readCartridgeMode() -> Result<UInt8,Failure> {
        sendAndWait("0C\0".bytes()).map { UInt8($0.hexString()) ?? .min }
    }
    
    /**
     *
     */
    func readPCBVersion() -> Result<UInt8,Failure> {
        sendAndWait("h\0".bytes()).map { UInt8($0.hexString()) ?? .min }
    }
    
    func readVoltage() -> Result<Voltage?,Failure> {
        sendAndWait("C\0".bytes())
            .map { UInt8($0.hexString()) ?? .min }
            .map(Voltage.init)
    }
    
    /**
     *
     */
    func readHeader<Platform: Gibby.Platform>(forPlatform platform: Platform.Type) -> Result<Platform.Header,Swift.Error> {
        setVoltage(forPlatform: platform)
            .read(byteCount: platform.headerRange.count) { (serialDevice, progress) in
                if progress.completedUnitCount == 0 {
                    serialDevice.send("0\0".bytes())
                    
                    // SET: 'RAM' disabled -------------------------------------
                    if platform is GameboyClassic.Type {
                        serialDevice.setBank(0x00, at: 0x0000)
                    }

                    serialDevice.seek(toAddress: platform.headerRange.lowerBound)
                    serialDevice.startReading(forPlatform: platform)
                }
                else if progress.isFinished {
                    serialDevice.send("0\0".bytes())
                }
                else {
                    serialDevice.send("1".bytes())
                }
        }
        .map(Platform.Header.init)
        .checkHeader()
    }
    
    /**
     *
     */
    func readClassicCartridge(progress update: ((Progress) -> ())? = nil) -> Result<GameboyClassic.Cartridge,Failure> {
        readHeader(forPlatform: GameboyClassic.self).flatMap {
            readClassicCartridge(forHeader: $0, progress: update)
        }
    }
    
    /**
     *
     */
    func readClassicSaveData(progress update: ((Progress) -> ())? = nil) -> Result<Data,Failure> {
        readHeader(forPlatform: GameboyClassic.self).flatMap {
            readClassicCartridgeSaveData(forHeader: $0, progress: update)
        }
    }
    
    /**
     *
     */
    func restoreClassicSaveData(_ saveData: Data, progress update: ((Progress) -> ())? = nil) -> Result<Success,Failure> {
        readHeader(forPlatform: GameboyClassic.self).flatMap {
            restoreClassicCartridgeSaveData(
                saveData,
                forHeader :$0,
                progress  :update
            )
            .flatMap { _ in self }
        }
    }
    
    func deleteClassicSaveData(progress update: ((Progress) -> ())? = nil) -> Result<Success,Failure> {
        readHeader(forPlatform: GameboyClassic.self).flatMap {
            restoreClassicCartridgeSaveData(
                Data(count :$0.ramSize),
                forHeader  :$0,
                progress   :update
            )
            .flatMap { _ in self }
        }
    }
}

extension Result where Success: Gibby.Cartridge, Failure == Swift.Error {
    @available(OSX 10.15, *)
    /**
     *
     */
    public func check(MD5 md5: String) -> Result<Success,Failure> {
        flatMap { cartridge in
            let md5HexString = cartridge.md5?.hexString(separator: "").lowercased() ?? ""
            guard md5HexString == md5.lowercased() else {
                return .failure(SerialDeviceError<Success.Platform>.mismatchedMD5(computed: md5HexString, expected: md5))
            }
            return .success(cartridge)
        }
    }
    
    /**
     *
     */
    public func write(toDirectoryPath path: String) -> Result<Success,Failure> {
        flatMap { cartridge in
            do {
                let pathComponent = "\(cartridge.header.title).\(cartridge.fileExtension)"
                let filePathURL   = URL(fileURLWithPath: path).appendingPathComponent(pathComponent)
                try cartridge.write(to: filePathURL)
                return .success(cartridge)
            } catch {
                return .failure(error)
            }
        }
    }
}

