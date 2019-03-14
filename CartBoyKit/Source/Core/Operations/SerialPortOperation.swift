import ORSSerial

@objc
public protocol SerialPortOperationDelegate: NSObjectProtocol {
    @objc optional func portOperationWillBegin(_ operation: Operation)
    @objc optional func portOperationDidBegin(_ operation: Operation)
    @objc optional func portOperation(_ operation: Operation, didUpdate progress: Progress)
    @objc optional func portOperationDidComplete(_ operation: Operation)
}

class SerialPortOperation<Controller: CartridgeController>: OpenPortOperation<Controller> {
    enum Context: CustomDebugStringConvertible {
        enum Intent: CustomDebugStringConvertible {
            case read
            case write(Data)
            
            var debugDescription: String {
                switch self {
                case .read:
                    return "read"
                case .write(let data):
                    return "write(count: \(data.count) bytes; md5: \(data.md5.hexString(separator: "").lowercased()))"
                }
            }
        }
        
        case header
        
        case cartridge(Controller.Cartridge.Header, intent: Intent)
        indirect case bank(_ bank: Int, cartridge: Context)
        
        case saveFile(Controller.Cartridge.Header, intent: Intent)
        indirect case sram(_ bank: Int, saveFile: Context)

        var debugDescription: String {
            switch self {
            case .header:
                return "header"
            case .cartridge:
                return "cartridge"
            case .saveFile:
                return "save file"
            case .bank(let bank, let context):
                switch context {
                case .cartridge(_, let intent):
                    return "\r>>> bank: #\(bank), \(intent)"
                default:
                    return "\r>>> bank: #\(bank)"
                }
            case .sram(let bank, let context):
                switch context {
                case .saveFile(_, let intent):
                    return "\r>>> sram: #\(bank), \(intent)"
                default:
                    return "\r>>> sram: #\(bank)"
                }
            }
        }

        var header: Controller.Cartridge.Header? {
            switch self {
            case .cartridge(let header, _):
                return header
            case .bank(_, let cartridge):
                return cartridge.header!
            case .saveFile(let header, _):
                return header
            case .sram(_, let saveFile):
                return saveFile.header!
            default:
                return nil
            }
        }
        
        var byteCount: Int {
            switch self {
            case .header:
                return Controller.Cartridge.Platform.headerRange.count
            case .cartridge(let header, _):
                return header.romSize
            case .saveFile(let header, _):
                return header.ramSize
            case .bank(let bank, _):
                return bank > 1 ? header!.romBankSize : header!.romBankSize * 2
            case .sram:
                return header!.ramBankSize
            }
        }
    }
    
    required init(controller: Controller, context: Context, result: @escaping ((Data?) -> ())) {
        self.result   = result
        self.delegate = controller
        self.context  = context
        self.progress = Progress(totalUnitCount: Int64(context.byteCount))
        super.init(controller: controller)
    }
    
    var context: Context
    weak var delegate: SerialPortOperationDelegate?
    
    private      let    result: (Data?) -> ()
    private      let  progress: Progress
    private      var bytesRead: Data = .init() {
        didSet {
            progress.completedUnitCount = Int64(bytesRead.count)
            if progress.isFinished {
                complete()
            }
            else {
                if let delegate = self.delegate, delegate.responds(to: #selector(SerialPortOperationDelegate.portOperation(_:didUpdate:))) {
                    delegate.portOperation?(self, didUpdate: progress)
                }
            }
        }
    }
    
    private func complete() {
        self._isExecuting = false
        self._isFinished  = true
        
        if let delegate = self.delegate, delegate.responds(to: #selector(SerialPortOperationDelegate.portOperationDidComplete(_:))) {
            delegate.portOperationDidComplete?(self)
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
        
        if let delegate = self.delegate, delegate.responds(to: #selector(SerialPortOperationDelegate.portOperationWillBegin(_:))) {
            DispatchQueue.main.sync {
                delegate.portOperationWillBegin?(self)
            }
        }
        
        switch self.context {
        case .cartridge, .saveFile:
            if let delegate = self.delegate, delegate.responds(to: #selector(SerialPortOperationDelegate.portOperationDidBegin(_:))) {
                DispatchQueue.main.async {
                    delegate.portOperationDidBegin?(self)
                }
            }
            self._isExecuting = true
        default: ()
        }

        if case let .cartridge(header, _) = self.context, header.romBanks > 0 {
            let group = DispatchGroup()
            for bank in 1..<header.romBanks where self.isCancelled == false {
                group.enter()
                let operation = SerialPortOperation(controller: self.controller, context: .bank(bank, cartridge: context)) { data in
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
        else if case let .saveFile(header, intent) = self.context, header.ramBanks > 0 {
            let group = DispatchGroup()
            for bank in 0..<header.ramBanks where self.isCancelled == false {
                group.enter()
                var operation: SerialPortOperation! = nil
                switch intent {
                //--------------------------------------------------------------
                // Read 'RAM'
                case .read:
                    operation = SerialPortOperation(controller: self.controller, context: .sram(bank, saveFile: context)) { data in
                        if let data = data {
                            self.bytesRead.append(data)
                        }
                        group.leave()
                    }
                //--------------------------------------------------------------
                // Write 'RAM'
                case .write(let data):
                    let startAddress = bank * header.ramBankSize
                    let endAddress   = startAddress.advanced(by: header.ramBankSize)
                    let dataToWrite  = data[startAddress..<endAddress]
                    let context      = Context.sram(bank, saveFile: .saveFile(header, intent: .write(dataToWrite)))
                    
                    operation = SerialPortOperation(controller: self.controller, context: context) { data in
                        if let data = data {
                            self.bytesRead.append(data)
                        }
                        group.leave()
                    }
                }
                
                if let operation = operation {
                    self.controller.addOperation(operation)
                    group.wait()
                    
                    if operation.isCancelled {
                        self.cancel()
                    }
                }
                else {
                    group.leave()
                }
            }
        }
        
        switch self.context {
        case .cartridge, .saveFile: ()
        default:
            self._isExecuting = true
            if let delegate = self.delegate, delegate.responds(to: #selector(SerialPortOperationDelegate.portOperationDidBegin(_:))) {
                DispatchQueue.main.async {
                    delegate.portOperationDidBegin?(self)
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
            // Default to 'data'; only when the operation's intent is to 'write'
            // do we override the data being appended.
            var dataToAppend: Data = data
            
            if case let .sram(_, context) = self.context {
                switch context {
                case .cartridge(_, .write):
                    fatalError()
                case .saveFile(_, .write):
                    // Notes about [data.count * 64]:
                    //  1. A single 'acknowledgment' byte is returned when
                    //     performing write operations.
                    //  2. An empty, 64-byte long buffer is appended, allowing
                    //     the operation to progress.
                    //  3. What should the write operation's 'result' be? Do we
                    //     want to append the original data instead?
                    //----------------------------------------------------------
                    //  TO-DO:
                    //----------------------------------------------------------
                    //  Further consideration needs to be given to the size of
                    //  buffer created, and where the value should come from.
                    dataToAppend = Data(count: data.count *  64)
                default: ()
                }
            }
            
            self.bytesRead.append(dataToAppend)
        }
    }
}
