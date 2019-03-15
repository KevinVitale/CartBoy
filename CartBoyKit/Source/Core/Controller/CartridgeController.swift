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
    public func writeSaveFile(_ data: Data, header: Self.Cartridge.Header? = nil, result: @escaping ((Bool) -> ())) {
        if let header = header {
            guard header.ramSize == data.count else {
                result(false)
                return
            }
            self.addOperation(SerialPortOperation(controller: self, context: .saveFile(header, intent: .write(data))) { _ in
                result(true)
            })
        }
        else {
            self.readHeader {
                self.writeSaveFile(data, header: $0, result: result)
            }
        }
    }
    
    public func eraseSaveFile(header: Self.Cartridge.Header? = nil, result: @escaping ((Bool) -> ())) {
        if let header = header {
            self.writeSaveFile(Data(count: header.ramSize), header: header, result: result)
        }
        else {
            self.readHeader {
                guard let header = $0 else {
                    result(false)
                    return
                }
                self.writeSaveFile(Data(count: header.ramSize), header: header, result: result)
            }
        }
    }
}

extension CartridgeController where Self.Cartridge: FlashCart {
    public func writeROMFile(to flashCart: Self.Cartridge, result: @escaping ((Bool) -> ())) {
        let header = flashCart.header
        let data = Data(flashCart[0..<Self.Cartridge.Index(flashCart.count)])
        
        guard header.romSize == data.count else {
            result(false)
            return
        }
        self.addOperation(SerialPortOperation(controller: self, context: .cartridge(header, intent: .write(data))) { _ in
            result(true)
        })
    }
}
