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
    
    private let isReadyCondition = NSCondition()
    
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
        self.controller.openReader(delegate: self)
        self.isReadyCondition.whileLocked {
            while !self.isReady {
                self.isReadyCondition.wait()
            }
            self._isExecuting = true
            super.main()
        }
    }

    public func serialPortWasRemovedFromSystem(_ serialPort: ORSSerialPort) {
        self.cancel()
    }
    
    public func serialPortWasOpened(_ serialPort: ORSSerialPort) {
        defer {
            self.isReadyCondition.whileLocked {
                self._isReady = true
                self.isReadyCondition.signal()
            }
        }
        print(#file, #function, #line)
    }

    @objc public func serialPortWasClosed(_ serialPort: ORSSerialPort) {
        print(#file, #function, #line)
    }
    
    @objc public func serialPort(_ serialPort: ORSSerialPort, didReceive data: Data) {
    }
}
