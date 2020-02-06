import ORSSerial

/**
 A `SerialPortController` instance can:
    - `open` and `close` a serial port; and
    - `send` arbitruary data to said serial port; and
    - execute `SerialPacketOperations` submitted as operations.
 */
public protocol SerialPortController {
    ///
    var isOpen: Bool { get }

    /**
     */
    func openReader(delegate: ORSSerialPortDelegate?)
    
    /**
     */
    @discardableResult
    func closePort() -> Bool
    
    /**
     Notifies the receiver that the underlying serial port has been closed.
     
     Use this function to give the controller an opportunity to a prepare a full
     shutdown of its own state, such as _signaling_ locks.
     */
    func serialPortWasClosed()
    
    @discardableResult
    func send(_ data: Data?, timeout: UInt32?) -> Bool
}

extension Data {
    /**
     *
     */
    public static func bytes<Number: FixedWidthInteger>(forCommand command: String = "", number: Number, radix: Int = 16, terminate: Bool = true) -> Data? {
        let numberAsString  = String(number, radix: radix, uppercase: true)
        return ("\(command)\(numberAsString)" + (terminate ? "\0" : "")).data(using: .ascii)!
    }
}

extension SerialPortController {
    /**
     *
     */
    fileprivate func timeout(sending bytes: @escaping () -> Data?) -> Result<Self,Swift.Error> {
        dispatchPrecondition(condition: .notOnQueue(.main))
        return waitFor {
            SerialPortRequest(
                controller      :self,
                unitCount       :0,    /* Important: set this to '0', otherwise `perform` will call `self.send` twice. */
                timeoutInterval :0.5,
                packetByteSize  :1,    /* Note: ignored, because we'll never read any data (or get any response). */
                perform         :{ _ in self.send(bytes(), timeout: 250) },
                response        :$0
                ).start()
        }
        .map { _ in self }
    }
    
    /**
     *
     */
    fileprivate func requestFrom(numberOfBytes byteCount: Int64, _ update :@escaping (Progress) -> ()) -> Result<Data,Swift.Error> {
        dispatchPrecondition(condition: .notOnQueue(.main))
        return waitFor {
            SerialPortRequest(
                controller     :self,
                unitCount      :byteCount,
                packetByteSize :64,
                perform        :update,
                response       :$0
            ).start()
        }
    }
    
    /**
     *
     */
    fileprivate func sendTo(numberOfConfirmations count: Int64, _ update: @escaping (Progress) -> ()) -> Result<Data,Swift.Error> {
        dispatchPrecondition(condition: .notOnQueue(.main))
        return waitFor {
            SerialPortRequest(
                controller     :self,
                unitCount      :count,
                packetByteSize :1,
                perform        :update,
                response       :$0
            ).start()
        }
    }
}

public enum SerialPortSanityCheckError<SerialDevice: SerialPortController>: Error {
    case isNotType(SerialDevice.Type)
}

extension Result where Success: SerialPortController, Failure == Swift.Error {
    internal func isTypeOf<SerialDeviceType: SerialPortController>(_ serialDeviceType: SerialDeviceType.Type) -> Result<SerialDeviceType,Failure> {
        flatMap {
            guard let serialDevice = $0 as? SerialDeviceType else {
                return .failure(SerialPortSanityCheckError.isNotType(SerialDeviceType.self))
            }
            return .success(serialDevice)
        }
    }
    
    internal func timeout(sending bytes: @autoclosure @escaping () -> Data?) -> Result<Success, Failure> {
        flatMap { serialDevice in
            switch serialDevice.timeout(sending: bytes) {
            case .failure(_): return .success(serialDevice)
            case .success(_): return .success(serialDevice)
            }
        }
    }
    
    /**
     *
     */
    internal func read(byteCount: Int, progressDidUpdate callback: @escaping (Success, Progress) -> ()) -> Result<Data,Error> {
        flatMap { serialDevice in
            serialDevice.requestFrom(numberOfBytes: Int64(byteCount)) {
                callback(serialDevice, $0)
            }
        }
    }

    /**
     *
     */
    internal func write(numberOfConfirmations count: Int, progressDidUpdate callback: @escaping (Success, Progress) -> ()) -> Result<Data,Error> {
        flatMap { serialDevice in
            serialDevice.sendTo(numberOfConfirmations: Int64(count)) {
                callback(serialDevice, $0)
            }
        }
    }
    
    /**
     *
     */
    internal func sendAndWait(
        _ bytes                  :Data?,
        packetByteSize           :UInt = 1,
        isValidPacket dataCallback :@escaping (Success,Data?) -> Bool = { _,_ in true },
        willStart startCallback  :@escaping (Success) -> () = { _ in },
        didFinish finishCallback :@escaping (Success) -> () = { _ in }) -> Result<Data,Failure>
    {
        flatMap { serialDevice in
            waitFor {
                SerialPortRequest(
                    controller        :serialDevice,
                    unitCount         :1,
                    packetByteSize    :packetByteSize,
                    responseEvaluator :{ dataCallback(serialDevice, $0) },
                    perform           :{ progress in
                        if progress.completedUnitCount == 0 {
                            startCallback(serialDevice)
                            serialDevice.send(bytes, timeout: nil)
                        }
                        else if progress.isFinished {
                            finishCallback(serialDevice)
                        }
                    },
                    response        :$0
                ).start()
            }
        }
    }
    
    /**
     *
     */
    internal func sendAndWait(
        _ bytes: Data?,
        packetByteSize             :UInt = 1,
        isValidPacket dataCallback :@escaping (Success,Data?) -> Bool = { _,_ in true },
        willStart startCallback    :@escaping (Success) -> () = { _ in },
        didFinish finishCallback   :@escaping (Success) -> () = { _ in }) -> Result<Success,Failure>
    {
        sendAndWait(bytes,
                    packetByteSize :packetByteSize,
                    isValidPacket  :dataCallback,
                    willStart      :startCallback,
                    didFinish      :finishCallback
        ).flatMap { (_: Data) in self }
    }
    
    public func erase<C: Chipset>(flashCartridge chipset: C.Type) -> Result<Success,Failure> {
        C.erase(self)
    }
}
