import Foundation

extension Data {
    public static func random(_ count: Int) -> Data {
        return Data((0...count).map { _ in
            UInt8.random(in: 0...UInt8.max)
        })
    }
    
    public func hexString(separator: String = " ", radix: Int = 16) -> String {
        return map { String($0, radix: radix, uppercase: true) }.joined(separator: separator)
    }
}

extension Result where Success == Data, Failure == Swift.Error {
    public func write(toDirectoryPath path: String, fileName: @autoclosure @escaping () -> String) -> Result<URL,Failure> {
        flatMap { data in
            do {
                let filePathURL = URL(fileURLWithPath: path).appendingPathComponent(fileName())
                try data.write(to: filePathURL)
                return .success(filePathURL)
            } catch {
                return .failure(error)
            }
        }
    }
}

extension BinaryInteger {
    func bytes(radix: Int = 16, uppercase: Bool = true, using encoding: String.Encoding = .ascii) -> Data? {
        guard let data = String(self, radix: radix, uppercase: uppercase).data(using: encoding) else {
            return nil
        }
        return data
    }
}

extension String {
    public func bytes(using encoding: String.Encoding = .ascii) -> Data? {
        guard let data = self.data(using: encoding) else {
            return nil
        }
        return data
    }
}
