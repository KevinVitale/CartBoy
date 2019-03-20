import Foundation

@objc public protocol SerialPacketOperationDelegate: class, NSObjectProtocol {
    @objc func packetOperation(_ operation: Operation, didBeginWith intent: Any?)
    @objc func packetOperation(_ operation: Operation, didUpdate progress: Progress, with intent: Any?)
    @objc func packetOperation(_ operation: Operation, didComplete buffer: Data, with intent: Any?)
    
    @objc func packetLength(for intent: Any?) -> UInt
}
