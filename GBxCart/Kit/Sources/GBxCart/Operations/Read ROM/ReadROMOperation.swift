import Foundation
import ORSSerial

public final class ReadROMOperation: Operation {
    public required init(device: ORSSerialPort, memoryRange: MemoryRange, cleanup completion: (() -> Void)? = nil) {
        self.memoryRange = memoryRange
        super.init()
        
        self.completionBlock = { [weak self] in
            device.delegate = nil

            if let strongSelf = self, strongSelf.bytes.indices.overlaps(memoryRange.indices) {
                strongSelf.bytes = strongSelf.bytes[memoryRange.indices]
            }
            DispatchQueue.main.async {
                completion?()
            }
        }
        
        self.device = device
        self.device?.delegate = self
    }

    // Properties
    //-------------------------------------------------------------------------
    public private(set) var memoryRange: MemoryRange
    public private(set) var bytes = Data() {
        didSet {
            if isFinished || isCancelled {
                self.willChangeValue(forKey: "isExecuting")
                self.willChangeValue(forKey: "isFinished")
                self._isExecuting = false
                self.didChangeValue(forKey: "isFinished")
                self.didChangeValue(forKey: "isExecuting")
            }
        }
    }
    private var _isExecuting = false
    private var buffer = Data()
    private weak var device: ORSSerialPort?
}

extension ReadROMOperation {
    func buffer(_ bytes: Data) {
        self.buffer.append(bytes)
    }
    
    func appendAndResetBuffer() {
        self.bytes.append(self.buffer)
        self.buffer = Data()
    }
    
    var shouldAppendBuffer: Bool {
        return (64 - self.buffer.count) <= 0
    }
    
    var shouldContinueToRead: Bool {
        return self.bytes.count < self.memoryRange.bytesToRead
    }
}

extension ReadROMOperation {
    public override func start() {
        guard self.isReady else {
            return
        }
        self.willChangeValue(forKey: "isExecuting")
        Thread(target: self, selector: #selector(main), object: nil).start()
        self._isExecuting = true
        self.didChangeValue(forKey: "isExecuting")
    }
    
    public override func main() {
        try? self.device?.readBytes(at: self.memoryRange.startingAddress)
    }
    
    public override func cancel() {
        super.cancel()
        self.buffer = Data()
        self.bytes  = Data()
    }
    
    public override var isReady: Bool {
        return super.isReady && self.device?.isOpen ?? false
    }
    
    public override var isExecuting: Bool {
        return self._isExecuting
    }
    
    public override var isFinished: Bool {
        return bytes.count >= memoryRange.bytesToRead || isCancelled
    }
    
    public override var isAsynchronous: Bool {
        return true
    }
}

