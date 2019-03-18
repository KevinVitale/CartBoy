import Foundation
import ORSSerial

@objc protocol SerialPacketOperationDelegate: class, NSObjectProtocol {
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

final class SerialPacketOperation<Controller: SerialPortController>: OpenPortOperation<Controller> {
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
                    delegate.packetOperation(self, didUpdate: progress, with: self.intent)
                }
            }
        }
    }
    
    private func complete() {
        if self.isCancelled == false {
            self._isExecuting = false
            self._isFinished  = true
        }
        
        let upToCount = self.isCancelled ? 0 : self.progress.totalUnitCount
        let data = self.buffer.prefix(upTo: Int(upToCount))
        
        if let delegate = self.delegate, delegate.responds(to: #selector(SerialPacketOperationDelegate.packetOperation(_:didComplete:with:))) {
            delegate.packetOperation(self, didComplete: data, with: self.intent)
        }
        
        self.controller.close(wait: 10)
        self.result(data)
    }
    
    override func main() {
        super.main()
        self.progress.becomeCurrent(withPendingUnitCount: 0)
        
        self.isReadyCondition.whileLocked {
            while !self.isReady {
                self.isReadyCondition.wait()
            }
            
            self._isExecuting = true
            print(NSString(string: #file).lastPathComponent, #function, #line)

            if let delegate = self.delegate, delegate.responds(to: #selector(SerialPacketOperationDelegate.packetOperation(_:didBeginWith:))) {
                DispatchQueue.main.sync {
                    delegate.packetOperation(self, didBeginWith: self.intent)
                }
            }
        }
    }
    
    override func serialPortWasOpened(_ serialPort: ORSSerialPort) {
        defer {
            self.isReadyCondition.whileLocked {
                self._isReady = true
                self.isReadyCondition.signal()
            }
        }
        
        let packetLength = self.delegate?.packetLength(for: self.intent) ?? 0
        
        serialPort.startListeningForPackets(matching: ORSSerialPacketDescriptor(maximumPacketLength: packetLength, userInfo: nil) { data in
            return data!.count == packetLength
        })
    }
    
    override func serialPort(_ serialPort: ORSSerialPort, didReceivePacket packetData: Data, matching descriptor: ORSSerialPacketDescriptor) {
        self.buffer.append(packetData)
        
        if self.progress.isFinished {
            serialPort.stopListeningForPackets(matching: descriptor)
        }
    }
}
