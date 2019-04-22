import Foundation

extension NSCondition {
    func whileLocked<T>(_ body: () throws -> T) rethrows -> T {
        defer {
            unlock()
        }
        lock()
        return try body()
    }
}
