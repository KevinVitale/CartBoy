import ORSSerial

extension ReadROMOperation: ORSSerialPortDelegate {
    public func serialPortWasRemovedFromSystem(_ serialPort: ORSSerialPort) {
        print(#function)
        cancel()
    }
    
    public func serialPortWasClosed(_ serialPort: ORSSerialPort) {
        print(#function)
        cancel()
    }
    
    public func serialPortWasOpened(_ serialPort: ORSSerialPort) {
        print(#function)
    }
    
    
    public func serialPort(_ serialPort: ORSSerialPort, didReceive data: Data) {
        guard self.isCancelled == false else {
            return
        }
        
        self.buffer(data)
        
        if self.shouldAppendBuffer {
            self.appendAndResetBuffer()

            if self.shouldContinueToRead {
                serialPort.continueToRead()
            }
        }
    }
}
