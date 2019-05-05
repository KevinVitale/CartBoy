import Gibby
import ORSSerial

public final class InsideGadgetsReader<Cartridge: Gibby.Cartridge>: NSObject {
    init(controller: InsideGadgetsCartridgeController<Cartridge.Platform>) {
        self.controller = controller
    }

    let controller: InsideGadgetsCartridgeController<Cartridge.Platform>
}

extension InsideGadgetsReader: CartridgeReader, CartridgeArchiver {
    public func header(result: @escaping (Result<Cartridge.Platform.Header, CartridgeReaderError<Cartridge>>) -> ()) {
        fatalError("Reader does not support platform: \(Cartridge.Platform.self)")
    }
    
    public func cartridge(progress callback: @escaping (Double) -> (), result: @escaping (Result<Cartridge, CartridgeReaderError<Cartridge>>) -> ()) {
        fatalError("Reader does not support platform: \(Cartridge.Platform.self)")
    }

    public func backup(progress callback: @escaping (Double) -> (), result: @escaping (Result<Data, Error>) -> ()) {
        fatalError("Reader does not support platform: \(Cartridge.Platform.self)")
    }
    
    public func restore(data: Data, progress callback: @escaping (Double) -> (), result: @escaping (Result<(), Error>) -> ()) {
        fatalError("Reader does not support platform: \(Cartridge.Platform.self)")
    }
    
    public func delete(progress callback: @escaping (Double) -> (), result: @escaping (Result<(), Error>) -> ()) {
        fatalError("Reader does not support platform: \(Cartridge.Platform.self)")
    }
}

extension InsideGadgetsReader {
    func request<Number>(totalBytes: Number, timeout: TimeInterval = -1.0, packetSize: UInt = 64, prepare: @escaping (InsideGadgetsCartridgeController<Cartridge.Platform>) -> (), progress: @escaping (InsideGadgetsCartridgeController<Cartridge.Platform>, Progress) -> () = { (_, _) in }, responseEvaluator: @escaping ORSSerialPacketEvaluator = { _ in true}) -> Result<Data, SerialPortRequestError> where Number: FixedWidthInteger {
        var result: Result<Data, SerialPortRequestError> = Result(catching: {
            try await {
                self.controller.add(
                    self.controller.request(totalBytes: Int64(totalBytes)
                        , packetSize: packetSize
                        , timeoutInterval: timeout
                        , prepare: prepare
                        , progress: progress
                        , responseEvaluator: responseEvaluator
                        , result: $0
                    )
                )
            }
        })
        .mapError { $0 as! SerialPortRequestError }
        result = result
            .flatMap { data in
                self.controller.stop()
                return .success(data)
        }
        return result
    }
    
    func read<Number>(totalBytes: Number, startingAt address: Cartridge.Platform.AddressSpace, timeout: TimeInterval = -1.0, packetSize: UInt = 64, prepare: @escaping (InsideGadgetsCartridgeController<Cartridge.Platform>) -> (), progress update: @escaping (Progress) -> () = { _ in }, responseEvaluator: @escaping ORSSerialPacketEvaluator = { _ in true}) -> Result<Data, SerialPortRequestError> where Number: FixedWidthInteger {
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
    
    func header(prepare: @escaping (InsideGadgetsCartridgeController<Cartridge.Platform>) -> ()) -> Result<Cartridge.Platform.Header, SerialPortRequestError> {
        let headerRange = Cartridge.Platform.headerRange
        let readData = self
            .read(totalBytes: headerRange.count
                , startingAt: headerRange.lowerBound
                , prepare: { prepare($0) }
            )
        return readData.flatMap {
            let header = Cartridge.Platform.Header(bytes: $0)
            guard header.isLogoValid else {
                return .failure(.noError)
            }
            return .success(header)
        }
    }
}
