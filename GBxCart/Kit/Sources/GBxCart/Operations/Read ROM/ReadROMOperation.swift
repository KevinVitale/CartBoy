import Foundation
import ORSSerial
import Gibby

public class BaseReadOperation<Controller: ReaderController>: Operation, ORSSerialPortDelegate {
    public init(controller: Controller, numberOfBytesToRead bytesToRead: Int = 0, result: @escaping ((Data) -> ())) {
        self.bytesToRead = bytesToRead
        self.progress = Progress(totalUnitCount: Int64(bytesToRead))
        super.init()
        
        self.completionBlock = { [weak self] in
            controller.reader?.delegate = nil

            guard let strongSelf = self else {
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
    }
    
    private(set) weak var controller: Controller!
    private var executionThread: Thread?
    private var    _isExecuting: Bool = false
    private(set) var  bytesRead: Data = Data() {
        didSet {
            self.progress.completedUnitCount = Int64(bytesRead.count)
        }
    }
    private var      bytesCache: Data = Data()
    private var     bytesToRead: Int
    private let        progress: Progress
    private let isOpenCondition: NSCondition = NSCondition()

    private var isCacheFilled: Bool {
        return (64 - bytesCache.count) <= 0
    }

    func append(next data: Data) {
        self.bytesCache.append(data)
        if self.isCacheFilled {
            self.bytesRead.append(self.bytesCache)
            self.bytesCache = Data()
        }
    }
    
    public override func main() {
        self.isOpenCondition.whileLocked {
            do {
                try self.controller.openReader(delegate: self)
            }
            catch {
                cancel()
                return
            }
            
            while self.controller.reader?.isOpen == false {
                self.isOpenCondition.wait() // self.isOpenCondition.wait(until: Date().addingTimeInterval(5))
            }
            
            // Begin...
            self.willChangeValue(forKey: "isExecuting")
            self.didChangeValue(forKey: "isExecuting")
        }
    }
    
    public override var isExecuting: Bool {
        return self.controller.reader?.isOpen ?? false
    }

    public override var isFinished: Bool {
        return bytesRead.count >= bytesToRead || isCancelled
    }

    public override var isAsynchronous: Bool {
        return true
    }

    public func serialPortWasRemovedFromSystem(_ serialPort: ORSSerialPort) {
        cancel()
        self.willChangeValue(forKey: "isFinished")
        self.didChangeValue(forKey: "isFinished")
    }
    
    public func serialPortWasClosed(_ serialPort: ORSSerialPort) {
    }
    
    public func serialPortWasOpened(_ serialPort: ORSSerialPort) {
        self.isOpenCondition.whileLocked {
            self.isOpenCondition.signal()
        }
    }
    
    public func serialPort(_ serialPort: ORSSerialPort, didReceive data: Data) {
        self.append(next: data)

        if (self.bytesCache.isEmpty && !self.isFinished) {
            self.controller.sendContinueReading()
        }
        else {
            self.willChangeValue(forKey: "isFinished")
            self.didChangeValue(forKey: "isFinished")
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
        super.main()
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

    public override func main() {
        super.main()
        self.controller.sendStopBreak()
        self.controller.sendGo(to: 0)
        self.controller.sendBeginReading()
    }
}

extension NSCondition {
    fileprivate func whileLocked<T>(_ body: () throws -> T) rethrows -> T {
        defer {
            unlock()
        }
        lock()
        return try body()
    }
}
