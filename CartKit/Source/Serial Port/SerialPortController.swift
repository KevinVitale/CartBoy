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
     */
    func close(delegate: ORSSerialPortDelegate)
}

extension SerialPortController {
    func request(totalBytes unitCount: Int64, packetSize maxPacketLength: UInt, timeoutInterval: TimeInterval = -1.0, prepare block: @escaping ((Self) -> ()), progress update: @escaping (Self, _ with: Progress) -> (), responseEvaluator: @escaping ORSSerialPacketEvaluator, result: @escaping (Result<Data, SerialPortRequestError>) -> ()) -> SerialPortRequest<Self> {
        return SerialPortRequest(controller: self
            , unitCount: unitCount
            , timeoutInterval: timeoutInterval
            , maxPacketLength: maxPacketLength
            , responseEvaluator: { data in
                responseEvaluator(data!)
        }, perform: { progress in
            if progress.completedUnitCount == 0 {
                block(self)
            }
            else {
                update(self, progress)
            }
        }) {
            result($0)
        }
    }
}
