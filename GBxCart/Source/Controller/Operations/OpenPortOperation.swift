import ORSSerial

class OpenPortOperation<Controller: SerialPortController>: Operation, ORSSerialPortDelegate {
    init(controller: Controller) {
        self.controller = controller
    }
    
    let controller: Controller
    
    @objc var _isExecuting: Bool = false {
        willSet { self.willChangeValue(forKey: "isExecuting") }
        didSet  {  self.didChangeValue(forKey: "isExecuting") }
    }
    
    @objc var _isFinished: Bool = false {
        willSet { self.willChangeValue(forKey: "isFinished") }
        didSet  {  self.didChangeValue(forKey: "isFinished") }
    }
    
    private let isOpenCondition: NSCondition = NSCondition()
    
    override var isExecuting: Bool {
        return _isExecuting
    }
    
    override var isFinished: Bool {
        return _isFinished
    }
    
    override func cancel() {
        super.cancel()
        self._isExecuting = false
        self._isFinished = true
    }
    
    override func main() {
        self.isOpenCondition.whileLocked {
            do {
                try self.controller.openReader(delegate: self)
            }
            catch {
                cancel()
                return
            }
            
            while self.controller.isOpen == false {
                self.isOpenCondition.wait() // self.isOpenCondition.wait(until: Date().addingTimeInterval(5))
            }
        }
    }
    
    func serialPortWasRemovedFromSystem(_ serialPort: ORSSerialPort) {
        self.cancel()
    }
    
    func serialPortWasOpened(_ serialPort: ORSSerialPort) {
        self.isOpenCondition.whileLocked {
            self.isOpenCondition.signal()
        }
    }
    
    func serialPort(_ serialPort: ORSSerialPort, didReceive data: Data) {
    }
}
