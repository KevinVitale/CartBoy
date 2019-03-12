import ORSSerial
import Gibby

public protocol ReaderController: SerialPortController, SerialPortOperationDelegate {
    /// The associated platform that the adopter relates to.
    associatedtype Cartridge: Gibby.Cartridge
}

extension ReaderController {
    /**
     */
    public func readHeader(result: @escaping ((Self.Cartridge.Header?) -> ())) {
        self.addOperation(SerialPortOperation(controller: self, context: .header) {
            guard let data = $0 else {
                result(nil)
                return
            }
            result(Self.Cartridge.Header(bytes: data))
        })
    }
    
    /**
     */
    public func readCartridge(header: Self.Cartridge.Header? = nil, result: @escaping ((Self.Cartridge?) -> ())) {
        if let header = header {
            self.addOperation(SerialPortOperation(controller: self, context: .cartridge(header, intent: .read)) {
                guard let data = $0 else {
                    result(nil)
                    return
                }
                result(Self.Cartridge(bytes: data))
            })
        }
        else {
            self.readHeader {
                self.readCartridge(header: $0, result: result)
            }
        }
    }
    
    /**
     */
    public func readSaveFile(header: Self.Cartridge.Header? = nil, result: @escaping ((Data?, Self.Cartridge.Header) -> ())) {
        if let header = header {
            guard header.ramSize > 0 else {
                result(nil, header)
                return
            }
            self.addOperation(SerialPortOperation(controller: self, context: .saveFile(header, intent: .read)) {
                guard let data = $0 else {
                    result(nil, header)
                    return
                }
                result(data, header)
            })
        }
        else {
            self.readHeader {
                self.readSaveFile(header: $0, result: result)
            }
        }
    }
}

/**
 */
public enum ReaderControllerError: Error {
    case failedToOpen(ORSSerialPort?)
}
