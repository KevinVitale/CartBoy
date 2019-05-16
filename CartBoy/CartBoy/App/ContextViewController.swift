import Cocoa

class ContextViewController: NSViewController {
    let context = ControllerContext(label: contextLabel)
    
    final class var contextLabel: String {
        return "com.cartboy.\(type(of: self)).queue".lowercased()
    }
}
