import ORSSerial
import Gibby

/**
 A controller which manages the serial port interations as it relates to Gameboy
 readers and writesr.
 
 - note: `Cartridge` headers are required for all operations.
 - note: ROM files are _"read"_ & _"written"_, or _"erased"_ (the latter two, if they are a `FlashCart`).
 - note: Save files are _"backed-up"_, _"restored"_, or _"deleted"_, if the `Cartridge` has **SRAM** support.
 */
public protocol CartridgeController: SerialPortController, SerialPortOperationDelegate {
    /// The associated platform that the adopter relates to.
    associatedtype Cartridge: Gibby.Cartridge

    /**
     */
    func header(result: @escaping ((Self.Cartridge.Header?) -> ()))
    
    /**
     */
    func read(header: Self.Cartridge.Header?, result: @escaping ((Self.Cartridge?) -> ()))
    
    /**
     */
    func write<Cartridge: FlashCart>(to flashCart: Cartridge, result: @escaping (Bool) ->()) where Cartridge == Self.Cartridge
    
    /**
     */
    func erase<Cartridge: FlashCart>(flashCart: Cartridge, result: @escaping (Bool) ->()) where Cartridge == Self.Cartridge

    /**
     */
    func backup(header: Self.Cartridge.Header?, result: @escaping (Data?, Self.Cartridge.Header) -> ())
    
    /**
     */
    func restore(from backup: Data, header: Self.Cartridge.Header?, result: @escaping (Bool) -> ())
    
    /**
     */
    func delete(header: Self.Cartridge.Header?, result: @escaping (Bool) -> ())
}

extension CartridgeController {
    /**
     */
    public func header(result: @escaping ((Self.Cartridge.Header?) -> ())) {
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
    public func read(header: Self.Cartridge.Header? = nil, result: @escaping ((Self.Cartridge?) -> ())) {
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
            self.header {
                self.read(header: $0, result: result)
            }
        }
    }
}

extension CartridgeController where Cartridge: FlashCart {
    /**
     */
    public func write(to flashCart: Self.Cartridge, result: @escaping ((Bool) -> ())) {
        let header = flashCart.header
        let data = Data(flashCart[0..<Self.Cartridge.Index(flashCart.count)])
        
        guard header.romSize == data.count, flashCart.hasSufficentCapacity else {
            result(false)
            return
        }
        self.addOperation(SerialPortOperation(controller: self, context: .cartridge(header, intent: .write(data))) { _ in
            result(true)
        })
    }
    
    /**
     */
    public func erase(flashCart: Self.Cartridge, result: @escaping (Bool) ->()) {
        fatalError()
    }
}

extension CartridgeController {
    public func backup(header: Self.Cartridge.Header? = nil, result: @escaping ((Data?, Self.Cartridge.Header) -> ())) {
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
            self.header {
                self.backup(header: $0, result: result)
            }
        }
    }
    public func restore(from data: Data, header: Self.Cartridge.Header? = nil, result: @escaping ((Bool) -> ())) {
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
            self.header {
                self.restore(from: data, header: $0, result: result)
            }
        }
    }
    
    public func delete(header: Self.Cartridge.Header? = nil, result: @escaping ((Bool) -> ())) {
        if let header = header {
            self.restore(from: Data(count: header.ramSize), header: header, result: result)
        }
        else {
            self.header {
                guard let header = $0 else {
                    result(false)
                    return
                }
                self.restore(from: Data(count: header.ramSize), header: header, result: result)
            }
        }
    }
}

