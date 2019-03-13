import ORSSerial
import Gibby

public protocol CartridgeController: SerialPortController, SerialPortOperationDelegate {
    /// The associated platform that the adopter relates to.
    associatedtype Cartridge: Gibby.Cartridge
}

extension CartridgeController {
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

extension CartridgeController {
    public func write(header: Self.Cartridge.Header? = nil, saveFile data: Data, result: @escaping (() -> ())) {
        if let header = header {
            guard header.ramSize == data.count else {
                result()
                return
            }
            self.addOperation(SerialPortOperation(controller: self, context: .saveFile(header, intent: .write(data))) { _ in
                result()
            })
        }
        else {
            self.readHeader {
                self.write(header: $0, saveFile: data, result: result)
            }
        }
    }
    
    public func eraseSaveFile(header: Self.Cartridge.Header? = nil, result: @escaping (() -> ())) {
        if let header = header {
            self.addOperation(SerialPortOperation(controller: self, context: .saveFile(header, intent: .write(Data(count: header.ramSize)))) { _ in
                result()
            })
        }
        else {
            self.readHeader {
                self.eraseSaveFile(header: $0, result: result)
            }
        }
    }
}
