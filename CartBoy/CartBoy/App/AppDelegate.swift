import Cocoa
import ORSSerial

@NSApplicationMain
class AppDelegate: NSObject, NSApplicationDelegate {
    @IBOutlet var cartInfoController    :CartInfoViewController!
    @IBOutlet var productInfoController :ProductInfoViewController!
    
    func applicationDidFinishLaunching(_ aNotification: Notification) {
        SerialDeviceObserver.shared.register(self)
    }

    func applicationShouldTerminateAfterLastWindowClosed(_ sender: NSApplication) -> Bool {
        return true
    }
}

extension AppDelegate: SerialDeviceListener {
    func serialDeviceObserver(_ observer: SerialDeviceObserver, didRemove removedPorts: Set<ORSSerialPort>) {
        self.productInfoController.clearProductInfo(nil)
        self.cartInfoController.clearHeaderUI(nil)
    }
    
    func serialDeviceObserver(_ observer: SerialDeviceObserver, didAttach attachedPorts: Set<ORSSerialPort>) {
        print(attachedPorts)
        if attachedPorts.isEmpty == false {
            self.productInfoController.readProductInfo(self)
            self.cartInfoController.readHeader(self)
        }
    }
}
