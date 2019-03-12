import ORSSerial

@objc
public protocol ReadPortOperationDelegate: NSObjectProtocol {
    @objc optional func readOperationWillBegin(_ operation: Operation)
    @objc optional func readOperationDidBegin(_ operation: Operation)
    @objc optional func readOperation(_ operation: Operation, didRead progress: Progress)
    @objc optional func readOperationDidComplete(_ operation: Operation)
    
    @objc optional func romBankSize(for bank: Int) -> Int
}

class ReadPortOperation<Controller: ReaderController>: OpenPortOperation<Controller> {
    enum Context: CustomDebugStringConvertible {
        case header
        case cartridge(Controller.Cartridge.Header)
        case bank(_ bank: Int, header: Controller.Cartridge.Header)
        
        case saveFile(Controller.Cartridge.Header)
        case sram(_ bank: Int, header: Controller.Cartridge.Header)
        
        case address(_ address: Controller.Cartridge.Platform.AddressSpace)

        var debugDescription: String {
            switch self {
            case .header:
                return "header"
            case .cartridge:
                return "cartridge"
            case .saveFile:
                return "save file"
            case .address:
                return "address"
            case .bank:
                return "bank"
            case .sram:
                return "sram"
            }
        }
    }
    
    required init(controller: Controller, context: Context, length readLength: Int, result: @escaping ((Data?) -> ())) {
        self.result   = result
        self.delegate = controller
        self.context  = context
        self.progress = Progress(totalUnitCount: Int64(readLength))
        super.init(controller: controller)
    }
    
    var context: Context
    weak var delegate: ReadPortOperationDelegate?
    
    private      let    result: (Data?) -> ()
    private      let  progress: Progress
    private      var bytesRead: Data = .init() {
        didSet {
            progress.completedUnitCount = Int64(bytesRead.count)
            if progress.isFinished {
                complete()
            }
            else {
                if let delegate = self.delegate, delegate.responds(to: #selector(ReadPortOperationDelegate.readOperation(_:didRead:))) {
                    delegate.readOperation?(self, didRead: progress)
                }
            }
        }
    }
    
    private func complete() {
        self._isExecuting = false
        self._isFinished  = true
        
        if let delegate = self.delegate, delegate.responds(to: #selector(ReadPortOperationDelegate.readOperationDidComplete(_:))) {
            delegate.readOperationDidComplete?(self)
        }
        
        let upToCount = self.isCancelled ? 0 : self.progress.totalUnitCount
        let data = self.bytesRead.prefix(upTo: Int(upToCount))
        
        self.result(data)
    }
    
    override func cancel() {
        super.cancel()
        self.bytesRead.removeAll()
        complete()
    }

    override func main() {
        super.main()
        self.progress.becomeCurrent(withPendingUnitCount: 0)
        
        if let delegate = self.delegate, delegate.responds(to: #selector(ReadPortOperationDelegate.readOperationWillBegin(_:))) {
            DispatchQueue.main.sync {
                delegate.readOperationWillBegin?(self)
            }
        }
        
        switch self.context {
        case .cartridge, .saveFile:
            if let delegate = self.delegate, delegate.responds(to: #selector(ReadPortOperationDelegate.readOperationDidBegin(_:))) {
                DispatchQueue.main.async {
                    delegate.readOperationDidBegin?(self)
                }
            }
            self._isExecuting = true
        default: ()
        }

        if case let .cartridge(header) = self.context, header.romBanks > 0 {
            let group = DispatchGroup()
            for bank in 1..<header.romBanks where self.isCancelled == false {
                group.enter()
                let readLength = controller.romBankSize?(for: bank) ?? 0
                let operation = ReadPortOperation(controller: self.controller, context: .bank(bank, header: header), length: readLength) { data in
                    if let data = data {
                        self.bytesRead.append(data)
                    }
                    group.leave()
                }
                
                self.controller.addOperation(operation)
                group.wait()
                
                if operation.isCancelled {
                    self.cancel()
                }
            }
        }
        else if case let .saveFile(header) = self.context, header.ramBanks > 0 {
            let group = DispatchGroup()
            for bank in 0..<header.ramBanks where self.isCancelled == false {
                group.enter()
                let readLength = header.ramBankSize
                let operation = ReadPortOperation(controller: self.controller, context: .sram(bank, header: header), length: readLength) { data in
                    if let data = data {
                        self.bytesRead.append(data)
                    }
                    group.leave()
                }
                
                self.controller.addOperation(operation)
                group.wait()
                
                if operation.isCancelled {
                    self.cancel()
                }
            }
        }
        
        switch self.context {
        case .cartridge, .saveFile: ()
        default:
            self._isExecuting = true
            if let delegate = self.delegate, delegate.responds(to: #selector(ReadPortOperationDelegate.readOperationDidBegin(_:))) {
                DispatchQueue.main.async {
                    delegate.readOperationDidBegin?(self)
                }
            }
        }
    }
    
    override func serialPort(_ serialPort: ORSSerialPort, didReceive data: Data) {
        //----------------------------------------------------------------------
        // This is a *very* important check!
        //----------------------------------------------------------------------
        // It is possible that this operation has become the delegate of 'serialPort',
        // but is still receiving errant data reads from a prior read-operation (if
        // any), and that this operation hasn't yet notified its delegate that it
        // will begin. It's crtical that the controller/delegate has a chance
        // to send the appropriate commands to the device in order for this read
        // operation to append the correct data.
        //----------------------------------------------------------------------
        if (self.isExecuting) {
            self.bytesRead.append(data)
        }
    }
}
