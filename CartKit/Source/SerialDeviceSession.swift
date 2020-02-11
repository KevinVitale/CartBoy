import Gibby
import ORSSerial

private let queue = DispatchQueue(label: "com.cartboy.serialdevice.session.queue", qos: .unspecified)

struct SerialDeviceSession<Device: DeviceProfile> {
    static func open(_ callback: @escaping (Result<(SerialDevice<Device>),Error>) -> ()) {
        queue.async(flags: .barrier) {
            callback(Result { try SerialDevice(matching: Device.portProfile) })
        }
    }
    
    let serialDevice: SerialDevice<Device>
}

extension DeviceProfile {
    public static func open(_ callback: @escaping (Result<(SerialDevice<Self>),Error>) -> ()) {
        SerialDeviceSession<Self>.open(callback)
    }
}
