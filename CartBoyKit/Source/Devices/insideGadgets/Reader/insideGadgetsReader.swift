import Gibby
import ORSSerial

public final class InsideGadgetsReader<Cartridge: Gibby.Cartridge>: NSObject, ProgressReporting {
    init(controller: InsideGadgetsCartridgeController<Cartridge.Platform>) {
        self.controller = controller
    }
    
    public internal(set) var progress: Progress = .init()

    let controller: InsideGadgetsCartridgeController<Cartridge.Platform>
}

extension InsideGadgetsReader: CartridgeReader, CartridgeArchiver {
    public func header(result: @escaping (Result<Cartridge.Header, CartridgeReaderError<Cartridge>>) -> ()) {
        fatalError("Reader does not support platform: \(Cartridge.Platform.self)")
    }
    
    public func cartridge(progress callback: @escaping (Progress) -> (), result: @escaping (Result<Cartridge, CartridgeReaderError<Cartridge>>) -> ()) {
        fatalError("Reader does not support platform: \(Cartridge.Platform.self)")
    }

    public func backup(progress callback: @escaping (Progress) -> (), result: @escaping (Result<Data, Error>) -> ()) {
        fatalError("Reader does not support platform: \(Cartridge.Platform.self)")
    }
    
    public func restore(data: Data, progress callback: @escaping (Progress) -> (), result: @escaping (Result<(), Error>) -> ()) {
        fatalError("Reader does not support platform: \(Cartridge.Platform.self)")
    }
    
    public func delete(progress callback: @escaping (Progress) -> (), result: @escaping (Result<(), Error>) -> ()) {
        fatalError("Reader does not support platform: \(Cartridge.Platform.self)")
    }
}

extension InsideGadgetsReader {
    func request<Number>(totalBytes: Number, timeout: TimeInterval = -1.0, packetSize: UInt = 64, prepare: @escaping (InsideGadgetsCartridgeController<Cartridge.Platform>) -> (), progress: @escaping (InsideGadgetsCartridgeController<Cartridge.Platform>, Progress) -> () = { (_, _) in }, responseEvaluator: @escaping ORSSerialPacketEvaluator = { _ in true}) -> Result<Data, Error> where Number: FixedWidthInteger {
        return Result { try await {
            self.controller.add(
                self.controller
                    .request(totalBytes: Int64(totalBytes)
                        , packetSize: packetSize
                        , timeoutInterval: timeout
                        , prepare: prepare
                        , progress: progress
                        , responseEvaluator: responseEvaluator
                        , result: $0
                )
            )}
            }
            .map {
                self.controller.stop()
                return $0
        }
    }
    
    func read<Number>(totalBytes: Number, startingAt address: Cartridge.Platform.AddressSpace, timeout: TimeInterval = -1.0, packetSize: UInt = 64, prepare: @escaping (InsideGadgetsCartridgeController<Cartridge.Platform>) -> (), progress update: @escaping (Progress) -> () = { _ in }, responseEvaluator: @escaping ORSSerialPacketEvaluator = { _ in true}) -> Result<Data, Error> where Number: FixedWidthInteger {
        return self.request(totalBytes: totalBytes
            , timeout: timeout
            , packetSize: packetSize
            , prepare: {
                $0.stop()
                prepare($0)
                $0.go(to: address)
                $0.read()
            }
            , progress: { controller, progress in
                update(progress)
                controller.continue()
            }
            , responseEvaluator: { data in
                switch data!.count % 64 {
                case  0: return true && responseEvaluator(data!)
                case 32: return true && responseEvaluator(data!)
                default: return false
                }
            }
        )
    }
    
    func header(prepare: @escaping (InsideGadgetsCartridgeController<Cartridge.Platform>) -> ()) -> Result<Cartridge.Header, CartridgeReaderError<Cartridge>> {
        return Result { Cartridge.Platform.headerRange }
            .flatMap { headerRange in
                self.read(totalBytes: headerRange.count
                    , startingAt: headerRange.lowerBound
                    , prepare: { prepare($0) }
                )
            }
            .map { Cartridge.Header(bytes: $0) }
            .flatMap {
                guard $0.isLogoValid else {
                    return .failure(SerialPortRequestError.noError)
                }
                return .success($0)
            }
            .mapError { .invalidHeader($0) }
    }
}
