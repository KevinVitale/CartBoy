import Foundation
import ORSSerial
import Gibby

public final class ReadROMOperation<Gameboy: Platform>: Operation, ORSSerialPortDelegate {
    public required init<Result: PlatformMemory>(device: ORSSerialPort, memoryRange: MemoryRange, cleanup completion: ((Result?) -> ())? = nil) where Result.Platform == Gameboy {
        super.init()
        
        self.romData = ReadROMData(operation: self, memoryRange: memoryRange)
        self.completionBlock = { [weak self] in
            device.delegate = nil
            
            DispatchQueue.main.async {
                completion?(self?.romData.result())
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
    private var _isExecuting = false
    private weak var device: ORSSerialPort?
    private var romData: ReadROMData<Gameboy>!

    private func notifyExecutionStateChangeIfNecessary() {
        if isFinished || isCancelled {
            self.willChangeValue(forKey: "isExecuting")
            self.willChangeValue(forKey: "isFinished")
            self._isExecuting = false
            self.didChangeValue(forKey: "isFinished")
            self.didChangeValue(forKey: "isExecuting")
        }
    }
    
    // Operation
    //--------------------------------------------------------------------------
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
        /* FIXME: These 'sends' are too specific to GBxCart. */
        self.device?.send("0\0".data(using: .ascii)!)
        self.device?.send("A\(String(self.romData.startingAddress, radix: 16, uppercase: true))\0".data(using: .ascii)!)
        self.device?.send("R".data(using: .ascii)!)
    }
    
    public override func cancel() {
        super.cancel()
        self.romData = nil
    }
    
    public override var isReady: Bool {
        return super.isReady && self.device?.isOpen ?? false
    }
    
    public override var isExecuting: Bool {
        return self._isExecuting
    }
    
    public override var isFinished: Bool {
        return romData.isCompleted || isCancelled
    }
    
    public override var isAsynchronous: Bool {
        return true
    }
    
    // ORSSerialDelegate
    //--------------------------------------------------------------------------
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
        
        var stop: Bool = false
        self.romData.append(next: data, stop: &stop)
        if !stop {
            serialPort.send("1".data(using: .ascii)!)
        }
        else {
            self.notifyExecutionStateChangeIfNecessary()
        }
    }
}

