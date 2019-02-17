import Foundation
import ORSSerial
import Gibby

public final class ReadROMOperation<Controller: ReaderController>: Operation, ORSSerialPortDelegate {
    public required init<Result: PlatformMemory>(controller: Controller, memoryRange: MemoryRange, cleanup completion: ((Result?) -> ())? = nil) where Result.Platform == Controller.Platform {
        self.romData = ReadROMData<Controller.Platform>(
            startingAddress: Controller.Platform.AddressSpace(memoryRange.startingAddress)
              , bytesToRead: memoryRange.bytesToRead
        )
        super.init()
        
        self.completionBlock = { [weak self] in
            controller.reader.delegate = nil
            
            guard let strongSelf = self else {
                return
            }
            
            if strongSelf.isCancelled {
                strongSelf.romData.erase()
            }
            
            DispatchQueue.main.async {
                completion?(strongSelf.romData.result())
            }
        }
        
        self.device = controller.reader
        self.device?.delegate = self
    }
    
    // Typealiases
    //--------------------------------------------------------------------------
    public typealias Cartridge = Controller.Platform.Cartridge


    // Properties
    //--------------------------------------------------------------------------
    private var _isExecuting = false
    private weak var device: ORSSerialPort?
    private var romData: ReadROMData<Controller.Platform>
    private var thread: Thread? = nil

    private func notifyExecutionStateChangeIfNecessary() {
        if isFinished || isCancelled {
            self.willChangeValue(forKey: "isExecuting")
            self.willChangeValue(forKey: "isFinished")
            self._isExecuting = false
            self.didChangeValue(forKey: "isFinished")
            self.didChangeValue(forKey: "isExecuting")
        }
    }
    
    public override func cancel() {
        super.cancel()
        self.notifyExecutionStateChangeIfNecessary()
    }
    
    // Operation
    //--------------------------------------------------------------------------
    public override func start() {
        guard self.isReady else {
            return
        }
        self.willChangeValue(forKey: "isExecuting")
        self.thread = Thread(target: self, selector: #selector(main), object: nil)
        self._isExecuting = true
        self.didChangeValue(forKey: "isExecuting")

    }
    
    public override func main() {
        /* FIXME: These 'sends' are too specific to GBxCart. */
        self.device?.send("0\0".data(using: .ascii)!)
        self.device?.send("A\(String(self.romData.startingAddress, radix: 16, uppercase: true))\0".data(using: .ascii)!)
        self.device?.send("R".data(using: .ascii)!)
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
        guard let thread = self.thread else {
            cancel()
            return
        }
        thread.start()
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

