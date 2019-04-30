import ORSSerial

extension ORSSerialPortManager {
    public enum PortMatchingError: Error, CustomDebugStringConvertible {
        case noMatching(profile: PortProfile)
        
        public var debugDescription: String {
            switch self {
            case .noMatching(let profile):
                return "No ports found matching \(profile)."
            }
        }
    }
}

extension ORSSerialPortManager {
    public enum PortProfile: Equatable {
        case prefix(String)
        case usb(vendorID: Int, productID: Int)
        
        public static func ==(lhs: PortProfile, rhs: PortProfile) -> Bool {
            switch (lhs, rhs) {
            case (.prefix(let lhsPrefix), .prefix(let rhsPrefix)):
                return lhsPrefix == rhsPrefix
            case (.usb(let lhsVendorID, let lhsProductID), .usb(let rhsVendorID, let rhsProductID)):
                return lhsVendorID == rhsVendorID && lhsProductID == rhsProductID
            default:
                return false
            }
        }

        fileprivate func matcher() -> ((ORSSerialPort) -> Bool) {
            switch self {
            case .prefix(let prefix):
                return { $0.path.hasPrefix(prefix) }
            case .usb(let vendorID, let productID):
                return { $0.vendorID == vendorID && $0.productID == productID }
            }
        }
    }
    
    private static func match(_ profile: PortProfile) -> ORSSerialPort? {
        return shared()
            .availablePorts
            .filter(profile.matcher())
            .first
    }
    
    public static func port(matching profile: PortProfile) throws -> ORSSerialPort {
        guard let port = ORSSerialPortManager.match(profile) else {
            throw PortMatchingError.noMatching(profile: profile)
        }
        return port
    }
}

import IOKit.usb
extension ORSSerialPort {
    public var ioDeviceAttributes: NSDictionary {
        var itr: io_iterator_t = 0
        let result = IORegistryEntryCreateIterator(
            self.ioKitDevice
          , kIOServicePlane
          , IOOptionBits(kIORegistryIterateRecursively + kIORegistryIterateParents)
          , &itr
        )
        
        defer { IOObjectRelease(itr) }
        guard result == KERN_SUCCESS else {
            return [:]
        }

        var obj: io_object_t = 0
        var deviceProperties: NSDictionary = [:]
        repeat {
            obj = IOIteratorNext(itr)
            defer { IOObjectRelease(obj) }
            
            var value: Unmanaged<CFMutableDictionary>? = .passRetained([String:AnyHashable]() as! CFMutableDictionary)
            guard IORegistryEntryCreateCFProperties(obj, &value, kCFAllocatorDefault, 0) == KERN_SUCCESS
                , let properties = value?.takeRetainedValue() as CFMutableDictionary? as NSDictionary? else {
                    continue
            }

            guard let _ = properties[kUSBVendorID]  as? Int
                , let _ = properties[kUSBProductID] as? Int
                else {
                    continue
            }
            deviceProperties = properties
        } while obj != 0
        
        return deviceProperties
    }
    
    public var productID: Int {
        return (ioDeviceAttributes[kUSBProductID] as? Int) ?? NSNotFound
    }
    
    public var vendorID: Int {
        return (ioDeviceAttributes[kUSBVendorID] as? Int) ?? NSNotFound
    }
}
