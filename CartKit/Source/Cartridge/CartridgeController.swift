import Gibby
import ORSSerial


public protocol CartridgeController: SerialPortController {
    associatedtype Platform: Gibby.Platform
    
    func read<Number>(byteCount: Number, startingAt address: Platform.AddressSpace, timeout: TimeInterval, prepare: ((Self) -> ())?, progress: @escaping (Progress) -> (), responseEvaluator: @escaping ORSSerialPacketEvaluator) -> Result<Data, Error> where Number: FixedWidthInteger
    func scanHeader(_ result: @escaping (Result<Platform.Header, Error>) -> ())
}

public final class _InsideGadgetsController<Platform: Gibby.Platform>: ThreadSafeSerialPortController, CartridgeController {
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
    private let queue = OperationQueue()
    
    /**
     Opens the serial port.
     
     In addition to being opened, the serial port is explicitly configured as
     if it were device manufactured by insideGadgets.com before returning.
     
     - Returns: An open serial port.
     */
    public override func open() -> ORSSerialPort {
        return super.open().configuredAsGBxCart()
    }
    
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
    
    private var headerResult: Result<Platform.Header, Error> {
        return self.read(byteCount: Platform.headerRange.count
            , startingAt: Platform.headerRange.lowerBound
            , prepare: { _ in
                switch Platform.self {
                case is GameboyClassic.Type: (self as! _InsideGadgetsController<GameboyClassic>).toggleRAM(on: false)
                default: ()
                }
        }).map { .init(bytes: $0)}
    }
    
    public func read<Number>(byteCount: Number, startingAt address: Platform.AddressSpace, timeout: TimeInterval = -1.0, prepare: ((_InsideGadgetsController<Platform>) -> ())? = nil, progress update: @escaping (Progress) -> () = { _ in }, responseEvaluator: @escaping ORSSerialPacketEvaluator = { _ in true }) -> Result<Data, Error> where Number: FixedWidthInteger {
        precondition(Thread.current != .main)
        return Result {
            let data = try await {
                self.request(totalBytes: byteCount
                    , packetSize: 64
                    , timeoutInterval: timeout
                    , prepare: {
                        $0.stop()
                        prepare?($0)
                        $0.go(to: address)
                        $0.read()
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

    public func scanHeader(_ result: @escaping (Result<Platform.Header, Error>) -> ()) {
        self.queue.addOperation(BlockOperation {
            result(self.headerResult)
        })
    }
}

extension _InsideGadgetsController where Platform == GameboyClassic {
    @discardableResult
    fileprivate func toggleRAM(on enabled: Bool, timeout: UInt32 = 250) -> Bool {
        return set(bank: enabled ? 0x0A : 0x00, at: 0, timeout: timeout)
    }
    

    @discardableResult
    fileprivate func set<Number>(bank: Number, at address: Platform.AddressSpace, timeout: UInt32 = 250) -> Bool where Number : FixedWidthInteger {
        return ( send("B", number: address, radix: 16, timeout: timeout)
            &&   send("B", number:    bank, radix: 10, timeout: timeout))
    }
}
