import Cocoa
import ORSSerial

@NSApplicationMain
class AppDelegate: NSObject, NSApplicationDelegate {
    @IBOutlet var cartInfoController: CartInfoViewController!
    @IBOutlet var productInfoController: ProductInfoViewController!
    
    private var cleanup: () -> () = { }
    
    func applicationDidFinishLaunching(_ aNotification: Notification) {
        let observer = ORSSerialPortManager.shared().observe(\.availablePorts, options: [.initial, .new]) { _, change in
            if let _ = change.newValue?.filter({ $0.productID != NSNotFound || $0.vendorID != NSNotFound }).first {
                self.cartInfoController.readHeader(self)
                self.productInfoController.readProductInfo(self)
            }
        }
        self.cleanup = {
            observer.invalidate()
        }
    }

    func applicationWillTerminate(_ aNotification: Notification) {
        self.cleanup()
    }
    
    func applicationShouldTerminateAfterLastWindowClosed(_ sender: NSApplication) -> Bool {
        return true
    }
}
