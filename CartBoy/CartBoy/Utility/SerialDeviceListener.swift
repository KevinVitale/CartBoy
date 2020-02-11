import ORSSerial

protocol SerialDeviceListener: NSObjectProtocol {
    func serialDeviceObserver(_ observer: SerialDeviceObserver, didRemove removedPorts: Set<ORSSerialPort>)
    func serialDeviceObserver(_ observer: SerialDeviceObserver, didAttach attachedPorts: Set<ORSSerialPort>)
}
