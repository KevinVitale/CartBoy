import Foundation
import ORSSerial

public enum SerialPortRequestError: Error {
    case cancelled
    case removed
    case timedOut
    case noError
}

class SerialPortRequest<Controller: SerialPortController>: OpenPortOperation<Controller>, ProgressReporting {
    required init(controller: Controller,
                   unitCount: Int64,
             timeoutInterval: TimeInterval = -1.0,
             maxPacketLength: UInt = 64,
           responseEvaluator: @escaping ORSSerialPacketEvaluator = { _ in true},
               perform block: @escaping (Progress) -> (),
           response callback: @escaping (Result<Data,SerialPortRequestError>) -> ())
    {
        self.request = ORSSerialRequest(dataToSend: .init(),
                                          userInfo: nil,
                                   timeoutInterval: timeoutInterval,
                                responseDescriptor: ORSSerialPacketDescriptor(maximumPacketLength: maxPacketLength,
                                                                                         userInfo: nil,
                                                                                responseEvaluator: responseEvaluator)
        )
        self.perform  = block
        self.progress = Progress(totalUnitCount: unitCount)
        self.callback = callback
        super.init(controller: controller)
    }
    
    // MARK: - Private Properties
    //--------------------------------------------------------------------------
    private let    queue: DispatchQueue = .init(label: "com.cartkit.serialport.request.queue")
    private let  perform: (Progress) -> ()
    private let callback: (Result<Data,SerialPortRequestError>) -> ()
    private let  request: ORSSerialRequest
    private var   result: Result<Data,SerialPortRequestError> = .failure(.noError)
    private var response: Data = .init() {
        didSet {
            self.progress.completedUnitCount = Int64(self.response.count)
            self.checkProgress()
        }
    }
    
    private var packet: Data = .init() {
        didSet {
            if let packetLength = self.request.responseDescriptor?.maximumPacketLength, packetLength > 0, packet.count % Int(packetLength) == 0 {
                response.append(packet)
                packet.removeAll()
            }
        }
    }
    
    private func setupOperationTimeout() {
        let timeoutInterval        = self.request.timeoutInterval
        let deadline: DispatchTime = timeoutInterval >= 0 ? .now() + .seconds(Int(timeoutInterval)) : .distantFuture
        
        self.queue.asyncAfter(deadline: deadline) { [weak self] in
            if self?.isExecuting == true {
                self?.timedOut()
            }
        }
    }
    
    private func checkProgress() {
        if self.progress.isFinished {
            guard case .failure(.noError) = self.result else {
                self.complete()
                return
            }
            let upToCount = self.isCancelled ? 0 : self.progress.totalUnitCount
            let data      = self.response.prefix(upTo: Int(upToCount))
            self.result   = .success(data)
            self.complete()
        }
        else {
            self.perform(self.progress)
        }
    }
    
    // MARK: - Protocol Properties
    //--------------------------------------------------------------------------
    let progress: Progress

    // MARK: - Timed Out
    //--------------------------------------------------------------------------
    func timedOut() {
        self.result = .failure(.timedOut)
        self.complete()
    }
    
    // MARK: - Removed
    //--------------------------------------------------------------------------
    func portRemoved() {
        self.result = .failure(.removed)
        self.complete()
    }

    // MARK: - Cancel
    //--------------------------------------------------------------------------
    override func cancel() {
        self.result = .failure(.cancelled)
        super.cancel()
        self.complete()
    }
    
    // MARK: - Complete
    //--------------------------------------------------------------------------
    override final func complete() {
        super.complete()
        self.callback(result)
    }

    // MARK: - Main
    //--------------------------------------------------------------------------
    override func main() {
        super.main()
        
        self.setupOperationTimeout()
        self.perform(self.progress)
    }
    
    // MARK: - Removed
    //--------------------------------------------------------------------------
    override func serialPortWasRemovedFromSystem(_ serialPort: ORSSerialPort) {
        self.portRemoved()
    }

    // MARK: - Did Receive Data
    //--------------------------------------------------------------------------
    override func serialPort(_ serialPort: ORSSerialPort, didReceive data: Data) {
        let isValidPacket = self.request.responseDescriptor?.dataIsValidPacket(data) ?? false
        (isValidPacket && self.isExecuting) ? self.packet.append(data) : ()
    }
}

