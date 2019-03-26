import Foundation
import ORSSerial

open class ThreadSafeSerialPortController: NSObject, SerialPortController {
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
        /*
        if data != Data([0x31]) {
            print(#function, data.hexString(), String(data: data, encoding: .ascii)!)
        }
         */
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
    
    public func close(delegate: ORSSerialPortDelegate) {
        self.isOpenCondition.whileLocked {
            self.delegate = nil
            self.isOpenCondition.signal()
        }
    }
}
