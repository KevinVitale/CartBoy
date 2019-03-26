import Foundation
import ORSSerial


final class SerialPortOperation<Controller: SerialPortController>: OpenPortOperation<Controller> {
    // MARK: - Initialization
    //--------------------------------------------------------------------------
    convenience init(controller: Controller, progress: Progress, perform block: @escaping ((Progress) -> ()), appendData: @escaping (((Data) -> Bool)) = { _ in return true }, result: @escaping ((Data?) -> ())) {
        self.init(controller: controller)
        self.performBlock = block
        self.appendData = appendData
        self.progress = progress
        self.result = result
    }
    
    // MARK: - Parameters (Private)
    //--------------------------------------------------------------------------
    private var performBlock: ((Progress) -> ())!
    private var appendData: ((Data) -> (Bool))!
    private var result: ((Data?) -> ())!
    private var progress: Progress!
    private var buffer: Data = .init() {
        didSet {
            progress.completedUnitCount = Int64(buffer.count)
            if progress.isFinished {
                complete()
            }
            else {
                performBlock(progress)
            }
        }
    }

    // MARK: - Main
    //--------------------------------------------------------------------------
    override func main() {
        super.main()
        self.progress.becomeCurrent(withPendingUnitCount: 0)
        self.performBlock(progress)
    }
    
    // MARK: - Close
    //--------------------------------------------------------------------------
    override func serialPortWasClosed(_ serialPort: ORSSerialPort) {
        let upToCount = self.isCancelled ? 0 : self.progress.totalUnitCount
        let data = self.buffer.prefix(upTo: Int(upToCount))
        
        self.result(data)
        super.serialPortWasClosed(serialPort)
    }
    
    // MARK: - Did Receive Data
    //--------------------------------------------------------------------------
    override func serialPort(_ serialPort: ORSSerialPort, didReceive data: Data) {
        self.appendData(data) ? self.buffer.append(data) : ()
    }
}
