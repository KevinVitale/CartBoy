import ORSSerial

final class SerialDeviceObserver: NSObject {
    override init() {
        super.init()
        weak var weakSelf = self
        SerialDeviceObserver.observer = ORSSerialPortManager
            .shared()
            .observe(\.availablePorts, options: [.initial, .new, .old]) { value, change in
                let strongSelf = weakSelf!
                let removedPorts  = change.oldValue ?? []
                let attachedPorts = change.newValue?.filter({ $0.productID != NSNotFound || $0.vendorID != NSNotFound }) ?? []
                strongSelf.availablePorts = Set(value.availablePorts.filter({ $0.productID != NSNotFound || $0.vendorID != NSNotFound }))
                
                // Buffer 'some time' to allow the device to initialize (if being inserted)...
                var delay: DispatchTimeInterval = .seconds(0)
                
                switch change.kind {
                case .removal:
                    strongSelf.listeningObjects.forEach {
                        $0?.serialDeviceObserver(strongSelf, didRemove: Set(removedPorts))
                    }
                case .insertion :
                    delay = .milliseconds(750)
                    fallthrough
                case .setting   :
                    DispatchQueue.main.asyncAfter(deadline: .now() + delay) {
                        strongSelf.listeningObjects.forEach {
                            $0?.serialDeviceObserver(strongSelf, didAttach: Set(attachedPorts))
                        }
                    }
                default: (/*no-op*/)
                }
        }
    }
    
    deinit {
        SerialDeviceObserver.observer.invalidate()
    }
    
    private func canAdd(listener: SerialDeviceListener) -> Bool {
        !self.listeningObjects.contains(where: { $0?.isEqual(listener) ?? false })
    }
    
    func register(_ listeningObject: SerialDeviceListener) {
        if self.canAdd(listener: listeningObject) {
            weak var listener = listeningObject
            self.listeningObjects.append(listener)
            listeningObject.serialDeviceObserver(self, didAttach: availablePorts)
        }
    }
    
    @objc dynamic private(set) var availablePorts: Set<ORSSerialPort> = []
    
    private var listeningObjects: [SerialDeviceListener?] = []
    
    private static var observer: NSKeyValueObservation! = nil
    
    static let shared = SerialDeviceObserver()
}

