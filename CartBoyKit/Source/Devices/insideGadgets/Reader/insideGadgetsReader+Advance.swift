import Gibby

extension InsideGadgetsReader where Cartridge.Platform == GameboyAdvance {
    public func readHeader(result: @escaping (Cartridge.Header?) -> ()) {
        let range = Cartridge.Platform.headerRange
        let count = Int64(range.count)
        self.resetProgress(to: Int64(count))
        self.read(count, at: range.lowerBound, prepare: { _ in
        }) { data in
            defer { self.resetProgress(to: 0) }
            result(.init(bytes: data ?? Data(count: Int(count))))
        }
    }
}
