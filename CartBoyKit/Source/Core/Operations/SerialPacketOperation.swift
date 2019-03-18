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
    required init(controller: Controller, delegate: SerialPacketOperationDelegate? = nil, intent: PacketIntent) {
        self.intent   = intent
        self.progress = Progress(totalUnitCount: Int64(intent.count))
        super.init(controller: controller)
        
        self.delegate = delegate
    }
    
    private let intent: PacketIntent
    private let progress: Progress
    private weak var delegate: SerialPacketOperationDelegate?
    private weak var serialPort: ORSSerialPort? = nil
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
    }
    
    override func main() {
        super.main()
        self.progress.becomeCurrent(withPendingUnitCount: 0)
        
        print(NSString(string: #file).lastPathComponent, #function, #line)
        guard let serialPort = self.serialPort else {
            cancel()
            return
        }
        
        let packetLength = self.delegate?.packetLength(for: self.intent) ?? 0

        self._isExecuting = true
        
        serialPort.startListeningForPackets(matching: ORSSerialPacketDescriptor(maximumPacketLength: packetLength, userInfo: nil) { data in
            return data!.count == packetLength
        })
        
        if let delegate = self.delegate, delegate.responds(to: #selector(SerialPacketOperationDelegate.packetOperation(_:didBeginWith:))) {
            DispatchQueue.main.sync {
                delegate.packetOperation(self, didBeginWith: self.intent)
            }
        }
    }
    
    @objc override func serialPortWasOpened(_ serialPort: ORSSerialPort) {
        super.serialPortWasOpened(serialPort)
        self.serialPort = serialPort
    }
    
    override func serialPort(_ serialPort: ORSSerialPort, didReceivePacket packetData: Data, matching descriptor: ORSSerialPacketDescriptor) {
        print(NSString(string: #file).lastPathComponent, #function, #line, packetData)
        self.buffer.append(packetData)
    }
}
