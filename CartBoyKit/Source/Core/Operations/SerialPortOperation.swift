import Foundation
import ORSSerial


final class SerialPortOperation<Controller: SerialPortController>: OpenPortOperation<Controller>, ProgressReporting {
    // MARK: - Initialization
    //--------------------------------------------------------------------------
    convenience init(controller: Controller, unitCount: Int64, packetLength: Int = 64, perform block: @escaping ((Progress) -> ()), appendData: @escaping (((Data) -> Bool)) = { _ in return true }, result: @escaping ((Data?) -> ())) {
        self.init(controller: controller)
        self.performBlock = block
        self.appendData = appendData
        self.packetLength = packetLength
        self.progress = Progress(totalUnitCount: unitCount)
        self.result = result
        //----------------------------------------------------------------------
    }
    
    // MARK: - Parameters (Private)
    //--------------------------------------------------------------------------
    private var performBlock: ((Progress) -> ())!
    private var appendData: ((Data) -> (Bool))!
    private var packetLength: Int!
    private var pageData: Data = Data() {
        didSet {
            if let packetLength = packetLength, packetLength > 0, pageData.count % packetLength == 0 {
                buffer.append(pageData)
                pageData.removeAll()
            }
        }
    }
    private var result: ((Data?) -> ())!
    private(set) var progress: Progress = .init()
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
    
    override final func complete() {
        super.complete()
        let upToCount = self.isCancelled ? 0 : self.progress.totalUnitCount
        let data = self.buffer.prefix(upTo: Int(upToCount))
        
        self.result(data)
    }
    

    // MARK: - Main
    //--------------------------------------------------------------------------
    override func main() {
        super.main()
        self.performBlock(progress)
    }
    
    // MARK: - Close
    //--------------------------------------------------------------------------
    override func serialPortWasClosed(_ serialPort: ORSSerialPort) {
        super.serialPortWasClosed(serialPort)
    }
    
    // MARK: - Did Receive Data
    //--------------------------------------------------------------------------
    override func serialPort(_ serialPort: ORSSerialPort, didReceive data: Data) {
        // print(#function, data, data.hexString(separator: "").lowercased())
        self.appendData(data) ? self.pageData.append(data) : ()
    }
}
