import Foundation
import ORSSerial

open class ThreadSafeSerialPortController: NSObject, SerialPortController, SerialPacketOperationDelegate {
    /**
     */
    public required init(matching portProfile: ORSSerialPortManager.PortProfile) throws {
        self.reader = try ORSSerialPortManager.port(matching: portProfile)
        super.init()
    }
    
    ///
    fileprivate let reader: ORSSerialPort
    
    ///
    private let isOpenCondition = NSCondition()
    
    ///
    private var currentDelegate: ORSSerialPortDelegate? = nil // Prevents 'deinit'
    private var        delegate: ORSSerialPortDelegate? {
        get { return reader.delegate }
        set {
            currentDelegate = newValue
            reader.delegate = newValue
        }
    }
    
    @discardableResult
    open func open() -> ORSSerialPort {
        self.reader.open()
        return self.reader
    }

    /**
     */
    public final func openReader(delegate: ORSSerialPortDelegate?) {
        self.isOpenCondition.whileLocked {
            while self.currentDelegate != nil {
                self.isOpenCondition.wait()
            }
            
            // print("Continuing...")
            self.delegate = delegate
            //------------------------------------------------------------------
            DispatchQueue.main.sync {
                if self.reader.isOpen == false {
                    self.open()
                }
            }
        }
    }
    
    /**
     */
    @discardableResult
    public func send(_ data: Data?, timeout: UInt32? = nil) -> Bool {
        defer {
            if let timeout = timeout {
                usleep(timeout)
            }
        }
        guard let data = data else {
            return false
        }
        return self.reader.send(data)
    }
    
    @discardableResult
    public func send<Number>(_ command: String, number: Number, radix: Int = 16, terminate: Bool = true, timeout: UInt32? = nil) -> Bool where Number : FixedWidthInteger {
        let numberAsString = String(number, radix: radix, uppercase: true)
        let data = ("\(command)\(numberAsString)" + (terminate ? "\0" : "")).data(using: .ascii)!
        return self.send(data, timeout: timeout)
    }
    
}

extension ThreadSafeSerialPortController {
    ///
    public var isOpen: Bool {
        return self.reader.isOpen
    }
    
    /**
     */
    @discardableResult
    public final func close() -> Bool {
        return self.reader.close()
    }
}

extension ThreadSafeSerialPortController {
    /**
     */
    @objc public func packetOperation(_ operation: Operation, didComplete intent: Any?) {
        self.isOpenCondition.whileLocked {
            self.delegate = nil
            self.isOpenCondition.signal()
        }
    }
}

extension SerialPortController where Self: ThreadSafeSerialPortController {
    /**
     Peforms a `block` operation while the serial port is open.
     */
    func whileOpened<Context>(_ intent: SerialPacketOperation<Self, Context>.Intent, perform block: @escaping (_ progress: Progress) -> (), callback: @escaping (Data?) -> ()) throws {
        SerialPacketOperation<Self, Context>(delegate: self, intent: intent, perform: block, result: callback).start()
    }
}
