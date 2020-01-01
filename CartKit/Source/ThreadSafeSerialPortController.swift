import Foundation
import ORSSerial

/**
 A controller that blocks access to a serial port (described by `portProfile`)
 while opened.
 */
open class ThreadSafeSerialPortController: NSObject, SerialPortController {
    /**
     Creates an instance of the receiver **iff** the serial port described by
     `portProfile` is connected to system.
     
     - parameter portProfile: Describes the serial port to be controlled.
     */
    init(matching portProfile: ORSSerialPortManager.PortProfile) throws {
        self.reader = try ORSSerialPortManager.port(matching: portProfile)
        super.init()
    }
    
    /// The underlying serial port.
    fileprivate let reader: ORSSerialPort
    
    /// A lock & checkpoint for whether the `reader` is opened by the receiver.
    private let isOpenCondition = NSCondition()
    
    /// Retain a strong reference. Prevents _deinit_ of `reader.delegate`.
    private var currentDelegate: ORSSerialPortDelegate? = nil
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
            //------------------------------------------------------------------
            self.delegate = delegate
            //------------------------------------------------------------------
            if self.reader.isOpen == false {
                self.open()
            }
        }
    }
    
    /**
     */
    @discardableResult
    func send(_ data: Data?, timeout: UInt32? = nil) -> Bool {
        defer {
            if let timeout = timeout {
                usleep(timeout)
            }
        }
        guard let data = data else {
            return false
        }
        // log(data)
        return self.reader.send(data)
    }
    
    @discardableResult
    func send<Number>(_ command: String, number: Number, radix: Int = 16, terminate: Bool = true, timeout: UInt32? = nil) -> Bool where Number : FixedWidthInteger {
        let numberAsString = String(number, radix: radix, uppercase: true)
        let data = ("\(command)\(numberAsString)" + (terminate ? "\0" : "")).data(using: .ascii)!
        return self.send(data, timeout: timeout)
    }
    
    private func log(_ data: Data) {
        if data != Data([0x31]) {
            print(#function, data.hexString(), String(data: data, encoding: .ascii)!)
        }
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
    public final func closePort() -> Bool {
        return self.reader.close()
    }
    
    public func serialPortWasClosed() {
        self.isOpenCondition.whileLocked {
            self.delegate = nil
            self.isOpenCondition.signal()
        }
    }
}

extension ThreadSafeSerialPortController {
    func waitFor( atMost timeout: TimeInterval = -1,
             _ responseEvaluator: @escaping ORSSerialPacketEvaluator = AnyResponse,
               fromRequest block: @escaping () -> () ) -> Result<Data, Error>
    {
        Result { try await {
            request(totalBytes: 1,
                    packetSize: 1,
               timeoutInterval: timeout,
                       prepare: { _ in block() },
                      progress: { _, _ in },
             responseEvaluator: responseEvaluator,
                        result: $0).start()
            }
        }
    }
}

let AnyResponse:         ORSSerialPacketEvaluator = { _ in true }
let TerminatingResponse: ORSSerialPacketEvaluator = { $0!.starts(with: [0x31]) }
