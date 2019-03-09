import ORSSerial

/**
 */
class BaseReadOperation<Controller: ReaderController>: Operation, ORSSerialPortDelegate {
    /**
     */
    init(controller: Controller, bytesToRead: Range<Int>, result: @escaping ((Data) -> ())) {
        self.bytesToRead = bytesToRead
        self.progress    = Progress(totalUnitCount: Int64(bytesToRead.count))
        
        super.init()
        
        let previousDelegate = controller.reader.delegate
        self.completionBlock = { [weak self] in
            controller.reader.delegate = previousDelegate
            
            guard let strongSelf = self else {
                return
            }
            
            DispatchQueue.main.async {
                let upToCount = strongSelf.isCancelled ? 0 : bytesToRead.count
                result(strongSelf.bytesRead.prefix(upTo: upToCount))
            }
        }
        
        self.controller = controller
    }
    
    typealias BytesToRead = Range<Int>

    ///
    private let progress: Progress
    
    ///
    private let isOpenCondition: NSCondition = NSCondition()
    
    ///
    var _isExecuting: Bool = false {
        willSet {
            if newValue != _isExecuting {
                self.willChangeValue(forKey: "isExecuting")
            }
        }
        didSet {
            self.didChangeValue(forKey: "isExecuting")
        }
    }
    
    ///
    private(set) weak var controller: Controller!
    
    ///
    var bytesRead: Data = Data() {
        didSet {
            self.progress.completedUnitCount = Int64(bytesRead.count)
        }
    }
    
    ///
    private(set) var bytesToRead: BytesToRead

    ///
    override func main() {
        self.isOpenCondition.whileLocked {
            do {
                try self.controller.openReader(delegate: self)
            }
            catch {
                cancel()
                return
            }
            
            while self.controller.reader.isOpen == false {
                self.isOpenCondition.wait() // self.isOpenCondition.wait(until: Date().addingTimeInterval(5))
            }
        }
        self._isExecuting = true
    }

    /**
     */
    override func cancel() {
        super.cancel()
        self.bytesRead.removeAll()
        self._isExecuting = false
        self.willChangeValue(forKey: "isFinished")
        self.didChangeValue(forKey: "isFinished")
    }
    
    override var isExecuting: Bool {
        return _isExecuting
    }

    /**
     */
    override var isFinished: Bool {
        return bytesRead.count >= bytesToRead.count || isCancelled
    }

    /**
     */
    func serialPortWasRemovedFromSystem(_ serialPort: ORSSerialPort) {
        cancel()
    }
    
    /**
     */
    func serialPortWasOpened(_ serialPort: ORSSerialPort) {
        self.isOpenCondition.whileLocked {
            self.isOpenCondition.signal()
        }
    }
    
    /**
     */
    func serialPort(_ serialPort: ORSSerialPort, didReceive data: Data) {
        self.bytesRead.append(data)

        if (self.bytesRead.count % Controller.cacheSize) == 0 {
            if !self.isFinished {
                self.controller.continueReading()
            }
            else {
                self.controller.stopReading()
                self.willChangeValue(forKey: "isFinished")
                self.didChangeValue(forKey: "isFinished")
            }
        }
    }
}

