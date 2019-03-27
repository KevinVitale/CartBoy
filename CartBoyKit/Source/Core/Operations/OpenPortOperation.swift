import ORSSerial

class OpenPortOperation<Controller: SerialPortController>: BlockOperation, ORSSerialPortDelegate {
    init(controller: Controller) {
        self.delegate = controller
        self.controller = controller
        self.transactionID = UUID()
        super.init()
        
        self.completionBlock = {
            controller.close()
        }
    }

    private(set) var delegate: SerialPortController? = nil
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

    override var isExecuting: Bool {
        return _isExecuting
    }
    
    override var isFinished: Bool {
        return _isFinished
    }
    
    override var isReady: Bool {
        return _isReady && super.isReady
    }
    
    override var isAsynchronous: Bool {
        return true
    }

    override public func cancel() {
        super.cancel()
        self._isExecuting = false
        self._isFinished = true
    }
    
    @objc func complete() {
        if !self.isCancelled {
            self._isExecuting = false
            self._isFinished = true
        }
    }
    
    @objc override func start() {
        if self.isAsynchronous {
            Thread(target: self, selector: #selector(self.main), object: nil).start()
        }
        else {
            main()
        }
    }
    
    @objc override func main() {
        self.controller.openReader(delegate: self)
        self.isReadyCondition.whileLocked {
            while !self.isReady {
                self.isReadyCondition.wait()
            }
            self._isExecuting = true
            super.main()
        }
    }

    func serialPortWasRemovedFromSystem(_ serialPort: ORSSerialPort) {
        self.cancel()
    }
    
    func serialPortWasOpened(_ serialPort: ORSSerialPort) {
        defer {
            self.isReadyCondition.whileLocked {
                self._isReady = true
                self.isReadyCondition.signal()
            }
        }
    }

    @objc func serialPortWasClosed(_ serialPort: ORSSerialPort) {
        controller.close(delegate: self)
    }
    
    @objc func serialPort(_ serialPort: ORSSerialPort, didReceive data: Data) {
    }
}
