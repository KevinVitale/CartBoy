import Foundation
import ORSSerial
import Gibby

/**
 A `ThreadSafeSerialPortController` generic to `DeviceProfile`.
 */
public class SerialDevice<Device: DeviceProfile>: ThreadSafeSerialPortController {
    /**
     Opens a serial port, the allows `Device` to configure it as needed before
     being returned.
     
     - returns: An opened serial port configured
     */
    public override func open() -> ORSSerialPort {
        Device.configure(serialPort: super.open())
    }
    
    /**
     The returned `Result` attempts to locate a serial port that matches the
     `portProfile` descibed by `Device`. A device which cannot be found results
     in `failure`.
     
     - note: The returned `Result` is only representative of a device which has been
     found _connected_ to the system; it is not yet opened.

     - returns: A `Result` which can be mapped to requests that reads and writes
                to the serial port.
     */
    public static func connect() -> Result<SerialDevice<Device>,Error> {
        Result { try SerialDevice(matching: Device.portProfile) }
    }
}

public enum CartridgeFlashError<FlashCartridge: CartKit.FlashCartridge>: Error {
    case unsupportedChipset(FlashCartridge.Type)
}
