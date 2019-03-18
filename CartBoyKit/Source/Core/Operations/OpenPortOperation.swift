import ORSSerial

class OpenPortOperation<Controller: SerialPortController>: Operation, ORSSerialPortDelegate {
    init(controller: Controller) {
        self.controller = controller
        self.transactionID = UUID()
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
                print("Waiting...")
                self.isOpenCondition.wait() // self.isOpenCondition.wait(until: Date().addingTimeInterval(5))
            }
        }
    }
    
    @objc func serialPortWasRemovedFromSystem(_ serialPort: ORSSerialPort) {
        self.cancel()
    }
    
    @objc func serialPortWasOpened(_ serialPort: ORSSerialPort) {
        self.isOpenCondition.whileLocked {
            print(#file, #function, #line)
            self.isOpenCondition.signal()
        }
    }

    @objc func serialPortWasClosed(_ serialPort: ORSSerialPort) {
        print(#function)
    }
    
    @objc func serialPort(_ serialPort: ORSSerialPort, didReceive data: Data) {
        print(#function)
    }
    
    @objc func serialPort(_ serialPort: ORSSerialPort, requestDidTimeout request: ORSSerialRequest) {
        print(#function)
    }
    
    @objc func serialPort(_ serialPort: ORSSerialPort, didEncounterError error: Error) {
        print(#function)
    }
    
    @objc func serialPort(_ serialPort: ORSSerialPort, didReceiveResponse responseData: Data, to request: ORSSerialRequest) {
        print(#function)
    }
    
    @objc func serialPort(_ serialPort: ORSSerialPort, didReceivePacket packetData: Data, matching descriptor: ORSSerialPacketDescriptor) {
        print(#function)
    }
}
