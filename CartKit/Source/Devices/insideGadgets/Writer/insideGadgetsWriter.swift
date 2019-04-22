import Gibby
import ORSSerial

public final class InsideGadgetsWriter<FlashCartridge: CartKit.FlashCartridge>: NSObject, ProgressReporting {
    init(controller: InsideGadgetsCartridgeController<FlashCartridge.Platform>) {
        self.controller = controller
    }
    
    public internal(set) var progress: Progress = .init()

    let controller: InsideGadgetsCartridgeController<FlashCartridge.Platform>
}

extension InsideGadgetsWriter: CartridgeWriter {
    public func erase(progress callback: @escaping (Progress) -> (), result: @escaping (Result<(), Error>) -> ()) {
        fatalError("Writer does not support platform: \(FlashCartridge.Platform.self)")
    }
    
    public func write(_ flashCartridge: FlashCartridge, progress callback: @escaping (Progress) -> (), result: @escaping (Result<(), Error>) -> ()) {
        fatalError("Writer does not support platform: \(FlashCartridge.Platform.self)")
    }
}

extension InsideGadgetsWriter {
    func request<Number>(totalBytes: Number, timeout: TimeInterval = -1.0, packetSize: UInt = 64, prepare: @escaping (InsideGadgetsCartridgeController<FlashCartridge.Platform>) -> (), progress: @escaping (InsideGadgetsCartridgeController<FlashCartridge.Platform>, Progress) -> () = { (_, _) in }, responseEvaluator: @escaping ORSSerialPacketEvaluator = { _ in true}) -> Result<Data, Error> where Number: FixedWidthInteger {
        return Result { try await {
            self.controller.add(
                self.controller.request(totalBytes: Int64(totalBytes)
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
    
    func sendAndWait(totalBytes: Int64 = 1, timeout: TimeInterval = -1.0, _ prepare: @escaping (InsideGadgetsCartridgeController<FlashCartridge.Platform>) -> (), responseEvaluator: @escaping ORSSerialPacketEvaluator = { _ in true}) -> Result<Data, Error> {
        return self.request(totalBytes: totalBytes
            , timeout: timeout
            , packetSize: 1
            , prepare: prepare
            , responseEvaluator: responseEvaluator
        )
    }
    
    func read<Number>(totalBytes: Number, startingAt address: FlashCartridge.Platform.AddressSpace, timeout: TimeInterval = -1.0, packetSize: UInt = 64, prepare: ((InsideGadgetsCartridgeController<FlashCartridge.Platform>) -> ())? = nil, progress update: @escaping (Progress) -> () = { _ in }, responseEvaluator: @escaping ORSSerialPacketEvaluator = { _ in true}) -> Result<Data, Error> where Number: FixedWidthInteger {
        return self.request(totalBytes: totalBytes
            , timeout: timeout
            , packetSize: packetSize
            , prepare: {
                $0.stop()
                prepare?($0)
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
}
