import Foundation
import ORSSerial

final class SerialPacketOperation<Controller: SerialPortController, Context>: OpenPortOperation<Controller> {
    enum Intent {
        case read(count: Int, context: Context)
        case write(data: Data, count: Int, context: Context)
        
        fileprivate var count: Int {
            switch self {
            case .read(let count, _):
                return count
            case .write(let data, let count, _):
                guard count != 0 else {
                    return data.count
                }
                return data.count / count
            }
        }
    }

    convenience init(delegate: Controller, intent: Intent, perform block: ((Progress) -> ())? = nil, appendData: (((Data) -> Bool))? = nil, result: @escaping ((Data?) -> ())) {
        self.init(controller: delegate)

        self.result   = result
        self.intent   = intent
        self.progress = Progress(totalUnitCount: Int64(intent.count))
        self.appendData = appendData
        self.performBlock = block
    }
    
    private var intent: Intent! = nil
    private var progress: Progress! = nil
    private var result: ((Data?) -> ())! = nil
    private var performBlock: ((Progress) -> ())? = nil
    private var appendData: ((Data) -> (Bool))? = nil
    private var buffer: Data = .init() {
        didSet {
            progress.completedUnitCount = Int64(buffer.count)
            if progress.isFinished {
                complete()
            }
            else {
                if let performBlock = self.performBlock {
                    performBlock(self.progress)
                }
                else if let delegate = self.delegate, delegate.responds(to: #selector(SerialPacketOperationDelegate.packetOperation(_:didUpdate:with:))) {
                    if case let packetLength = Int64(self.delegate?.packetLength?(for: self.intent) ?? 1), progress.completedUnitCount % packetLength == 0 {
                        delegate.packetOperation?(self, didUpdate: progress, with: self.intent)
                    }
                }
            }
        }
    }

    override func main() {
        super.main()

        self.progress.becomeCurrent(withPendingUnitCount: 0)

        if let performBlock = self.performBlock {
            performBlock(self.progress)
        }
        else if let delegate = self.delegate, delegate.responds(to: #selector(SerialPacketOperationDelegate.packetOperation(_:didBeginWith:))) {
            DispatchQueue.main.async {
                delegate.packetOperation?(self, didBeginWith: self.intent)
            }
        }
    }

    @objc override func serialPortWasClosed(_ serialPort: ORSSerialPort) {
        let upToCount = self.isCancelled ? 0 : self.progress.totalUnitCount
        let data = self.buffer.prefix(upTo: Int(upToCount))
        
        self.result(data)
        
        if let delegate = self.delegate, delegate.responds(to: #selector(SerialPacketOperationDelegate.packetOperation(_:didComplete:))) {
            delegate.packetOperation?(self, didComplete: self.intent)
        }
        
        super.serialPortWasClosed(serialPort)
    }
    
    @objc override func serialPort(_ serialPort: ORSSerialPort, didReceive data: Data) {
        if let appendData = self.appendData {
            appendData(data) ? self.buffer.append(data) : ()
        }
        else {
            self.buffer.append(data)
        }
    }
}
