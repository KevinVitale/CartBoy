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
    static func bytes<Number: FixedWidthInteger>(forCommand command: String, number: Number, radix: Int = 16, terminate: Bool = true) -> Data? {
        let numberAsString  = String(number, radix: radix, uppercase: true)
        return ("\(command)\(numberAsString)" + (terminate ? "\0" : "")).data(using: .ascii)!
    }
}

extension SerialPortController {
    func command(sending bytes: @escaping () -> Data?) -> Result<Self,Swift.Error> {
        dispatchPrecondition(condition: .notOnQueue(.main))
        return waitFor {
            SerialPortRequest(
                controller        :self,
                unitCount         :0,
                timeoutInterval   :0.5,
                maxPacketLength   :1,
                responseEvaluator :{ _ in true },
                perform           :{ _ in self.send(bytes(), timeout: 250) },
                response          :$0
            ).start()
        }
        .map { _ in self }
    }
    
    func read(byteCount: Int64, didUpdateData update :@escaping (Progress) -> ()) -> Result<Data,Swift.Error> {
        dispatchPrecondition(condition: .notOnQueue(.main))
        return waitFor {
            SerialPortRequest(
                controller :self,
                unitCount  :byteCount,
                perform    :update,
                response   :$0
            ).start()
        }
    }
    
    func write(numberOfConfirmations count: Int64, didUpdateData update :@escaping (Progress) -> ()) -> Result<Data,Swift.Error> {
        dispatchPrecondition(condition: .notOnQueue(.main))
        return waitFor {
            SerialPortRequest(
                controller      :self,
                unitCount       :count,
                maxPacketLength :1,
                perform         :update,
                response        :$0
            ).start()
        }
    }
}

extension Result where Success: SerialPortController, Failure == Swift.Error {
    func command(sending bytes: @autoclosure @escaping () -> Data?) -> Result<Success, Failure> {
        flatMap { serialDevice in
            switch serialDevice.command(sending: bytes) {
            case .failure(_): return .success(serialDevice)
            case .success(_): return .success(serialDevice)
            }
        }
    }
    
    func read(byteCount: Int, didUpdateData callback: @escaping (Success, Progress) -> ()) -> Result<Data,Error> {
        flatMap { serialDevice in
            serialDevice.read(byteCount: Int64(byteCount)) {
                callback(serialDevice, $0)
            }
        }
    }
    
    func write(numberOfConfirmations count: Int, didUpdateData callback: @escaping (Success, Progress) -> ()) -> Result<Data,Error> {
        flatMap { serialDevice in
            serialDevice.write(numberOfConfirmations: Int64(count)) {
                callback(serialDevice, $0)
            }
        }
    }
    
    func sendAndWait(_ bytes: Data?, willStart startCallback: @escaping (Success) -> () = { _ in }, didFinish finishCallback: @escaping (Success) -> () = { _ in }) -> Result<Data,Failure> {
        flatMap { serialDevice in
            waitFor {
                SerialPortRequest(
                    controller      :serialDevice,
                    unitCount       :1,
                    maxPacketLength :1,
                    perform         :{ progress in
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
}
