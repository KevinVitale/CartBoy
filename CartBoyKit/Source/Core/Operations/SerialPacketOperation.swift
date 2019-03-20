import Foundation
import ORSSerial

public final class SerialPacketOperation<Controller: CartridgeController>: OpenPortOperation<Controller> {
    enum Intent {
        case read(count: Int, context: Context)
        case write(data: Data, context: Context)
        
        fileprivate var count: Int {
            switch self {
            case .read(let count, _):
                return count
            case .write(let data, _):
                return data.count
            }
        }
    }
    
    enum Context {
        case header
        case cartridge(Controller.Cartridge.Header)
        case saveFile(Controller.Cartridge.Header)
    }
    
    override private init(controller: Controller, block: (() -> ())? = nil) {
        super.init(controller: controller, block: block)
    }
    
    convenience init(delegate: Controller, intent: Intent, result: @escaping ((Data?) -> ())) {
        self.init(controller: delegate)

        self.result   = result
        self.intent   = intent
        self.progress = Progress(totalUnitCount: Int64(intent.count))
    }
    
    private var intent: Intent! = nil
    private var progress: Progress! = nil
    private var result: ((Data?) -> ())! = nil
    private var buffer: Data = .init() {
        didSet {
            progress.completedUnitCount = Int64(buffer.count)
            if progress.isFinished {
                complete()
            }
            else {
                if let delegate = self.delegate, delegate.responds(to: #selector(SerialPacketOperationDelegate.packetOperation(_:didUpdate:with:))) {
                    if case let packetLength = Int64(self.delegate?.packetLength?(for: self.intent) ?? 1), progress.completedUnitCount % packetLength == 0 {
                        delegate.packetOperation?(self, didUpdate: progress, with: self.intent)
                    }
                }
            }
        }
    }

    public override func main() {
        super.main()

        self.progress.becomeCurrent(withPendingUnitCount: 0)

        if let delegate = self.delegate, delegate.responds(to: #selector(SerialPacketOperationDelegate.packetOperation(_:didBeginWith:))) {
            DispatchQueue.main.async {
                delegate.packetOperation?(self, didBeginWith: self.intent)
            }
        }
    }

    @objc public override func serialPortWasClosed(_ serialPort: ORSSerialPort) {
        let upToCount = self.isCancelled ? 0 : self.progress.totalUnitCount
        let data = self.buffer.prefix(upTo: Int(upToCount))
        
        self.result(data)
        
        if let delegate = self.delegate, delegate.responds(to: #selector(SerialPacketOperationDelegate.packetOperation(_:didComplete:))) {
            delegate.packetOperation?(self, didComplete: self.intent)
        }
        
        super.serialPortWasClosed(serialPort)
    }
    
    @objc public override func serialPort(_ serialPort: ORSSerialPort, didReceive data: Data) {
        self.buffer.append(data)
    }
}
