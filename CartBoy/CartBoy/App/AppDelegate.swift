import Cocoa
import ORSSerial

@NSApplicationMain
class AppDelegate: NSObject, NSApplicationDelegate {
    @IBOutlet var cartInfoController: CartInfoViewController!
    @IBOutlet var productInfoController: ProductInfoViewController!
    
    private var cleanup: () -> () = { }
    
    func applicationDidFinishLaunching(_ aNotification: Notification) {
        let observer = ORSSerialPortManager.shared().observe(\.availablePorts, options: [.initial, .new, .old]) { _, change in
            if change.oldValue == nil || change.kind == .removal {
                self.productInfoController.clearProductInfo(nil)
                self.cartInfoController.clearHeaderUI(nil)
            }
            
            if change
                .newValue?
                .filter({ $0.productID != NSNotFound || $0.vendorID != NSNotFound })
                .isEmpty == false
            {
                let delay: DispatchTimeInterval = (change.kind == .insertion ? .milliseconds(1250) : .seconds(0))
                DispatchQueue.main.asyncAfter(deadline: .now() + delay) {
                    self.productInfoController.readProductInfo(self)
                    DispatchQueue.main.asyncAfter(deadline: .now() + .milliseconds(125)) {
                        self.cartInfoController.readHeader(self)
                    }
                }
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
