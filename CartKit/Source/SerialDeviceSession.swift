import Gibby
import ORSSerial

private let queue = DispatchQueue(label: "com.cartboy.serialdevice.session.queue", qos: .unspecified)

public struct SerialDeviceSession<Device: DeviceProfile> {
    public static func open(_ callback: @escaping (Result<(SerialDevice<Device>),Error>) -> ()) {
        queue.async(flags: .barrier) {
            callback(Result { try SerialDevice(matching: Device.portProfile) })
        }
    }
    
    let serialDevice: SerialDevice<Device>
}
