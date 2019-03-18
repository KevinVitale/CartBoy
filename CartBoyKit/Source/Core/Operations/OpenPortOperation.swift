import ORSSerial

public class OpenPortOperation<Controller: SerialPortController>: Operation, ORSSerialPortDelegate {
    init(controller: Controller) {
        self.controller = controller
        self.transactionID = UUID()
        super.init()
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
        print(NSString(string: #file).lastPathComponent, #function, #line)
        self.controller.openReader(delegate: self)
    }

    deinit {
        print(NSString(string: #file).lastPathComponent, #function, #line)
    }
    
    public func serialPortWasRemovedFromSystem(_ serialPort: ORSSerialPort) {
        self.cancel()
    }
    
    public func serialPortWasOpened(_ serialPort: ORSSerialPort) {
        print(NSString(string: #file).lastPathComponent, #function, #line)
    }

    public func serialPortWasClosed(_ serialPort: ORSSerialPort) {
        print(NSString(string: #file).lastPathComponent, #function, #line)
    }
    
    public func serialPort(_ serialPort: ORSSerialPort, didReceive data: Data) {
    }
    
    public func serialPort(_ serialPort: ORSSerialPort, requestDidTimeout request: ORSSerialRequest) {
        print(NSString(string: #file).lastPathComponent, #function, #line)
    }
    
    public func serialPort(_ serialPort: ORSSerialPort, didEncounterError error: Error) {
        print(NSString(string: #file).lastPathComponent, #function, #line)
    }
    
    public func serialPort(_ serialPort: ORSSerialPort, didReceivePacket packetData: Data, matching descriptor: ORSSerialPacketDescriptor) {
    }
}
