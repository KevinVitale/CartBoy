import Foundation

@objc public protocol SerialPacketOperationDelegate: class, NSObjectProtocol {
    @objc optional func packetOperation(_ operation: Operation, didBeginWith intent: Any?)
    @objc optional func packetOperation(_ operation: Operation, didUpdate progress: Progress, with intent: Any?)
    @objc optional func packetOperation(_ operation: Operation, didComplete intent: Any?)
    
    @objc optional func packetLength(for intent: Any?) -> UInt
}
