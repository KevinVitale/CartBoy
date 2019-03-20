import Foundation
import ORSSerial

@objc public protocol SerialPacketOperationDelegate: class, NSObjectProtocol {
    @objc func packetOperation(_ operation: Operation, didBeginWith intent: Any?)
    @objc func packetOperation(_ operation: Operation, didUpdate progress: Progress, with intent: Any?)
    @objc func packetOperation(_ operation: Operation, didComplete buffer: Data, with intent: Any?)
    
    @objc func packetLength(for intent: Any?) -> UInt
}

enum PacketIntent {
    case read(count: Int, context: Any?)
    case write(data: Data)
    
    fileprivate var count: Int {
        switch self {
        case .read(let count, _):
            return count
        case .write(let data):
            return data.count
        }
    }
}

enum OperationContext {
    case header
    case cartridge
    case saveFile
}

public final class SerialPacketOperation<Controller: SerialPortController>: OpenPortOperation<Controller> {
    required init(controller: Controller, delegate: SerialPacketOperationDelegate? = nil, intent: PacketIntent, result: @escaping ((Data?) -> ())) {
        self.result   = result
        self.intent   = intent
        self.progress = Progress(totalUnitCount: Int64(intent.count))
        super.init(controller: controller)
        
        self.delegate = delegate
    }
    
    private weak var delegate: SerialPacketOperationDelegate?
    private let intent: PacketIntent
    private let progress: Progress
    private let result: (Data?) -> ()
    private let isReadyCondition = NSCondition()
    private var buffer: Data = .init() {
        didSet {
            progress.completedUnitCount = Int64(buffer.count)
            if progress.isFinished {
                complete()
            }
            else {
                if let delegate = self.delegate, delegate.responds(to: #selector(SerialPacketOperationDelegate.packetOperation(_:didUpdate:with:))) {
                    if case let packetLength = Int64(self.delegate?.packetLength(for: self.intent) ?? 0), progress.completedUnitCount % packetLength == 0 {
                        delegate.packetOperation(self, didUpdate: progress, with: self.intent)
                    }
                }
            }
        }
    }
    
    private func complete() {
        if self.isCancelled == false {
            self._isExecuting = false
            self._isFinished  = true
        }
        
        self.controller.close()
    }
    
    public override func main() {
        super.main()

        self.isReadyCondition.whileLocked {
            while !self.isReady {
                self.isReadyCondition.wait()
            }
            
            self.progress.becomeCurrent(withPendingUnitCount: 0)
            self._isExecuting = true

            if let delegate = self.delegate, delegate.responds(to: #selector(SerialPacketOperationDelegate.packetOperation(_:didBeginWith:))) {
                DispatchQueue.main.async {
                    delegate.packetOperation(self, didBeginWith: self.intent)
                }
            }
        }
    }
    
    public override func serialPortWasOpened(_ serialPort: ORSSerialPort) {
        defer {
            self.isReadyCondition.whileLocked {
                self._isReady = true
                self.isReadyCondition.signal()
            }
        }
    }
    
    public override func serialPortWasClosed(_ serialPort: ORSSerialPort) {
        let upToCount = self.isCancelled ? 0 : self.progress.totalUnitCount
        let data = self.buffer.prefix(upTo: Int(upToCount))
        
        self.result(data)
        
        if let delegate = self.delegate, delegate.responds(to: #selector(SerialPacketOperationDelegate.packetOperation(_:didComplete:with:))) {
            delegate.packetOperation(self, didComplete: data, with: self.intent)
        }
    }
    
    public override func serialPort(_ serialPort: ORSSerialPort, didReceive data: Data) {
        self.buffer.append(data)
    }
}
