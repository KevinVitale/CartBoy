import Foundation
import ORSSerial
import Gibby

public class BaseReadOperation<Controller: ReaderController>: Operation, ORSSerialPortDelegate {
    deinit {
        print(#function)
    }
    public init(controller: Controller, numberOfBytesToRead bytesToRead: Int = 0, result: @escaping ((Data) -> ())) {
        self.bytesToRead = bytesToRead
        print("Bytes to read ", bytesToRead)
        super.init()
        
        self.completionBlock = { [weak self] in
            print("Returning results...")
            controller.reader?.delegate = nil

            guard let strongSelf = self else {
                print("Self?")
                return
            }
            
            if strongSelf.isCancelled {
                strongSelf.bytesRead.removeAll()
            }
            
            DispatchQueue.main.async {
                result(strongSelf.bytesRead)
            }
        }
        
        self.controller = controller
        self.controller.reader?.delegate = self
    }
    
    private(set) weak var controller: Controller!
    private var executionThread: Thread?
    private var    _isExecuting: Bool = false
    private var       bytesRead: Data = Data()
    private var      bytesCache: Data = Data()
    private var     bytesToRead: Int

    private var isCacheFilled: Bool {
        return (64 - bytesCache.count) <= 0
    }
    
    private func notifyExecutionStateChangeIfNecessary() {
        if (isFinished || isCancelled) {
            self.willChangeValue(forKey: "isExecuting")
            self.willChangeValue(forKey: "isFinished")
            self._isExecuting = false
            self.didChangeValue(forKey: "isFinished")
            self.didChangeValue(forKey: "isExecuting")
        }
    }
    
    func append(next data: Data) {
        self.bytesCache.append(data)
        if self.isCacheFilled {
            self.bytesRead.append(self.bytesCache)
            self.bytesCache = Data()
        }
    }
    
    public override func cancel() {
        super.cancel()
        self.notifyExecutionStateChangeIfNecessary()
    }
    
    public override func start() {
        guard self.isReady else {
            return
        }
        self.willChangeValue(forKey: "isExecuting")
        self.executionThread = Thread(target: self, selector: #selector(main), object: nil)
        self.executionThread?.name = "\(self)"
        self._isExecuting = true
        self.didChangeValue(forKey: "isExecuting")
    }
    
    public override func main() {
        print(#function)
    }
    
    public override var isReady: Bool {
        return super.isReady && self.controller.reader?.isOpen ?? false
    }
    
    public override var isExecuting: Bool {
        return self._isExecuting
    }
    
    public override var isFinished: Bool {
        return bytesRead.count >= bytesToRead || isCancelled
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
        self.notifyExecutionStateChangeIfNecessary()
    }
    
    public func serialPortWasOpened(_ serialPort: ORSSerialPort) {
        guard let thread = self.executionThread else {
            cancel()
            return
        }
        thread.start()
        print(#function)
    }
    
    public func serialPort(_ serialPort: ORSSerialPort, didReceive data: Data) {
        guard serialPort == self.controller.reader else {
            cancel()
            return
        }
        
        guard self.isCancelled == false else {
            return
        }
        
        self.append(next: data)
        
        if !self.isFinished {
            self.controller.sendContinueReading()
        }
        else {
            self.notifyExecutionStateChangeIfNecessary()
        }
    }
}

public final class ReadHeaderOperation<Controller: ReaderController>: BaseReadOperation<Controller> {
    public required init(controller: Controller, result: ((Header?) -> ())? = nil) {
        super.init(controller: controller, numberOfBytesToRead: Controller.Platform.headerRange.count) { data in
            result?(Header(bytes: data))
        }
    }
    
    public typealias Header = Controller.Platform.Cartridge.Header

    public override func main() {
        self.controller.sendStopBreak()
        self.controller.sendGo(to: Controller.Platform.headerRange.lowerBound)
        self.controller.sendBeginReading()
    }
}

public final class ReadCartridgeOperation<Controller: ReaderController>: BaseReadOperation<Controller> {
    public required init(controller: Controller, header: Cartridge.Header, result: ((Cartridge?) -> ())? = nil) {
        self.header = header
        super.init(controller: controller, numberOfBytesToRead: header.romSize) { data in
            result?(Cartridge(bytes: data))
        }
    }
    
    private let header: Cartridge.Header
    
    public typealias Cartridge = Controller.Platform.Cartridge
    
    public override var isReady: Bool {
        return !header.isLogoValid && super.isReady
    }
    
    public override func main() {
        print(#function)
        self.controller.sendStopBreak()
        self.controller.sendGo(to: 0)
        self.controller.sendBeginReading()
    }
}
