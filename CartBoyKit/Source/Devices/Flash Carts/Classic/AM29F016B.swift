import Gibby

public struct AM29F016B: FlashCart {
    public init(bytes data: Data) {
        self.cartridge = Platform.Cartridge(bytes: data)
    }

    public typealias Platform = GameboyClassic
    public typealias Header   = Platform.Cartridge.Header
    public typealias Index    = Platform.Cartridge.Index
    
    private let cartridge: Platform.Cartridge
    
    public subscript(position: Index) -> Data.Element {
        return cartridge[Index(position)]
    }
    
    public var startIndex: Index {
        return Index(cartridge.startIndex)
    }
    
    public var endIndex: Index {
        return Index(cartridge.endIndex)
    }
    
    public func index(after i: Index) -> Index {
        return Index(cartridge.index(after: Int(i)))
    }
    
    public var fileExtension: String {
        return cartridge.fileExtension
    }
    
    public func write(to url: URL, options: Data.WritingOptions = []) throws {
        try self.cartridge.write(to: url, options: options)
    }
}
