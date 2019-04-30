import ORSSerial

/**
 A single-purpose `Operation` that is intended to be subclassed. When used with
 `ThreadSafeSerialPortController`, this class guarantees that access to the
 associated instance of `Controller` (and its underlying serial port) is
 thread-safe.
 
 When started, the receiver will attempt to open `Controller` for itself, waiting
 indefinitely until it has done so. Once opened, the port remains under exclusive
 control of the receiver, until the receiver is either cancelled, or completes.
 
 The receiver automatically closes the port when it moves to its `isFinished`
 state.
 
 - SeeAlso: ThreadSafeSerialPortController
 */
class OpenPortOperation<Controller: SerialPortController>: Operation, ORSSerialPortDelegate {
    init(controller: Controller) {
        self.controller = controller
        super.init()
        
        self.completionBlock = {
            controller.closePort()
        }
    }

    let controller: Controller

    private let isReadyCondition = NSCondition()
    
    @objc var _isExecuting: Bool = false {
        willSet { self.willChangeValue(forKey: "isExecuting") }
        didSet  {  self.didChangeValue(forKey: "isExecuting") }
    }
    
    @objc var _isFinished: Bool = false {
        willSet { self.willChangeValue(forKey: "isFinished") }
        didSet  {  self.didChangeValue(forKey: "isFinished") }
    }
    
    /// Defaults to `true` so that the receiver is eligble to be queued when
    /// being sumbitted to a `OperationQueue`.
    ///
    /// Once `main()` is called, this value gets set to `false` and then back to
    /// `true` once the port has been opened.
    @objc var _isReady: Bool = true {
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

    /**
     Blocks until the receiver has opened the `Controller` for itself.

     Subclasses should override this function expecting that when the call to
     `super.main()` returns, the port is open and under its exclusive control.
     */
    @objc override func main() {
        defer { self._isExecuting = true }
        self._isReady = false
        self.controller.openReader(delegate: self)
        self.isReadyCondition.whileLocked {
            while !self.isReady {
                self.isReadyCondition.wait()
            }
            super.main()
        }
    }

    func serialPortWasRemovedFromSystem(_ serialPort: ORSSerialPort) {
        self.cancel()
    }
    
    func serialPortWasOpened(_ serialPort: ORSSerialPort) {
        self.isReadyCondition.whileLocked {
            self._isReady = true
            self.isReadyCondition.signal()
        }
    }

    @objc func serialPortWasClosed(_ serialPort: ORSSerialPort) {
        controller.close(delegate: self)
    }
    
    @objc func serialPort(_ serialPort: ORSSerialPort, didReceive data: Data) {
    }
}
