import ORSSerial

protocol SerialDevice: class, NSObjectProtocol {
    func readBytes(at address: Int) throws
    func continueToRead()
    func stopSending()
}

extension ORSSerialPort: SerialDevice {
    func readBytes(at address: Int = 0) throws {
        stopSending()
        send("A\(String(address, radix: 16, uppercase: true))\0".data(using: .ascii)!)
        send("R".data(using: .ascii)!)
    }
    
    func continueToRead() {
        send("1".data(using: .ascii)!)
    }
    
    func stopSending() {
        send("0\0".data(using: .ascii)!)
    }
}
