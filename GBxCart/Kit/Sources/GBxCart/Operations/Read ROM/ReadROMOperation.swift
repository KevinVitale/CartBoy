import Foundation
import ORSSerial
import Gibby

public final class ReadROMOperation<SerialDevice: ORSSerialPort, Gameboy: Platform>: Operation, ORSSerialPortDelegate {
    public required init<Result: PlatformMemory>(device: ORSSerialPort, memoryRange: MemoryRange, cleanup completion: ((Result) -> ())? = nil) where Result.Platform == Gameboy {
        self.memoryRange = memoryRange
        super.init()
        
        self.completionBlock = { [weak self] in
            device.delegate = nil

            if let strongSelf = self, strongSelf.bytes.indices.overlaps(memoryRange.indices) {
                strongSelf.bytes = strongSelf.bytes[memoryRange.indices]
            }
            
            DispatchQueue.main.async {
                completion?(Result(bytes: self?.bytes ?? Data()))
            }
        }
        
        self.device = device
        self.device?.delegate = self
    }
    
    // Typealiases
    //--------------------------------------------------------------------------
    public typealias Cartridge = Gameboy.Cartridge


    // Properties
    //--------------------------------------------------------------------------
    public private(set) var memoryRange: MemoryRange
    private private(set) var bytes = Data() {
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
    
    public func serialPortWasRemovedFromSystem(_ serialPort: ORSSerialPort) {
        print(#function)
        cancel()
    }
    
    public func serialPortWasClosed(_ serialPort: ORSSerialPort) {
        print(#function)
        cancel()
    }
    
    public func serialPortWasOpened(_ serialPort: ORSSerialPort) {
        print(#function)
    }
    
    
    public func serialPort(_ serialPort: ORSSerialPort, didReceive data: Data) {
        guard self.isCancelled == false else {
            return
        }
        
        self.buffer(data)
        
        if self.shouldAppendBuffer {
            self.appendAndResetBuffer()
            
            if self.shouldContinueToRead {
                serialPort.continueToRead()
            }
        }
    }
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
        return (SerialDevice.pageSize - self.buffer.count) <= 0
    }
    
    var shouldContinueToRead: Bool {
        return self.bytes.count < self.memoryRange.bytesToRead
    }
}

