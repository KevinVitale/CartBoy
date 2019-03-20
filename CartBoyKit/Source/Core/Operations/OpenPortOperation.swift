import ORSSerial

public class OpenPortOperation<Controller: SerialPortController>: BlockOperation, ORSSerialPortDelegate {
    init(controller: Controller, block: (() -> ())? = nil) {
        self.controller = controller
        self.transactionID = UUID()
        super.init()
        
        if let block = block {
            addExecutionBlock(block)
        }
    }
    
    let controller: Controller
    let transactionID: UUID
    
    @objc var _isExecuting: Bool = false {
        willSet { self.willChangeValue(forKey: "isExecuting") }
        didSet  {  self.didChangeValue(forKey: "isExecuting") }
    }
    
    @objc var _isFinished: Bool = false {
        willSet { self.willChangeValue(forKey: "isFinished") }
        didSet  {  self.didChangeValue(forKey: "isFinished") }
    }
    
    @objc var _isReady: Bool = false {
        willSet { self.willChangeValue(forKey: "isReady") }
        didSet  {  self.didChangeValue(forKey: "isReady") }
    }

    override public var isExecuting: Bool {
        return _isExecuting
    }
    
    override public var isFinished: Bool {
        return _isFinished
    }
    
    override public var isReady: Bool {
        return _isReady && super.isReady
    }
    
    public override var isAsynchronous: Bool {
        return true
    }

    override public func cancel() {
        super.cancel()
        self._isExecuting = false
        self._isFinished = true
    }
    
    @objc public override func start() {
        if self.isAsynchronous {
            Thread(target: self, selector: #selector(self.main), object: nil).start()
        }
        else {
            main()
        }
    }

    @objc override public func main() {
        super.main()
        self.controller.openReader(delegate: self)
    }

    public func serialPortWasRemovedFromSystem(_ serialPort: ORSSerialPort) {
        self.cancel()
    }
    
    public func serialPortWasOpened(_ serialPort: ORSSerialPort) {
    }

    public func serialPortWasClosed(_ serialPort: ORSSerialPort) {
    }
    
    public func serialPort(_ serialPort: ORSSerialPort, didReceive data: Data) {
    }
    
    public func serialPort(_ serialPort: ORSSerialPort, requestDidTimeout request: ORSSerialRequest) {
    }
    
    public func serialPort(_ serialPort: ORSSerialPort, didEncounterError error: Error) {
    }
    
    public func serialPort(_ serialPort: ORSSerialPort, didReceivePacket packetData: Data, matching descriptor: ORSSerialPacketDescriptor) {
    }
}
