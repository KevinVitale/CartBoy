public enum Voltage: String, CustomDebugStringConvertible {
    case high = "5V"    // 5V
    case low  = "3.3V"  // 3_3V
    
    public var debugDescription: String {
        return self.rawValue
    }
}
