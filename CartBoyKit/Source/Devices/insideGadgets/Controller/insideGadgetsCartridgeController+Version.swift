extension InsideGadgetsCartridgeController {
    public struct Version: CustomStringConvertible {
        fileprivate init(major: Int = 1, minor: Int, revision: String) {
            self.major = major
            self.minor = minor
            self.revision = revision.lowercased()
        }
        
        public let major: Int
        public let minor: Int
        public let revision: String
        
        public var description: String {
            return "v\(major).\(minor)\(revision)"
        }
    }
}

extension InsideGadgetsCartridgeController {
    public static func version(result: @escaping (Version?) -> ()) throws {
        let controller = try InsideGadgetsCartridgeController()
        controller.add(SerialPortOperation(controller: controller, unitCount: 3, packetLength: 1, perform: { progress in
            guard progress.completedUnitCount > 0 else {
                controller.send("C\0".bytes())
                return
            }
            guard progress.completedUnitCount > 1 else {
                controller.send("h\0".bytes())
                return
            }
            guard progress.completedUnitCount > 2 else {
                controller.send("V\0".bytes())
                return
            }
        }) { data in
            guard let major = data?[0], let minor = data?[1], let revision = data?[2] else {
                result(nil)
                return
            }
            result(.init(major: Int(major), minor: Int(minor), revision: String(revision, radix: 16, uppercase: false)))
        })
    }
}
