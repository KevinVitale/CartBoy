import Cocoa
import CartKit
import ORSSerial

class SerialDeviceViewController<Device: DeviceProfile>: NSViewController {
    @IBOutlet weak var productInfoViewController: ProductInfoViewController!
    @IBOutlet weak var appDelegate: AppDelegate!
    
    var deviceProfile: DeviceProfile.Type = GBxCart.self

    override func awakeFromNib() {
        super.awakeFromNib()
        SerialDeviceObserver.shared.register(self)
    }

    func setup(with appDelegate: AppDelegate, inside productInfoViewController: ProductInfoViewController) {
        self.appDelegate = appDelegate
        self.productInfoViewController = productInfoViewController
    }
}

extension SerialDeviceViewController: SerialDeviceListener {
    func serialDeviceObserver(_ observer: SerialDeviceObserver, didRemove removedPorts: Set<ORSSerialPort>) {
        self.productInfoViewController?.clearProductInfo(nil)
        self.appDelegate?.cartInfoController.clearHeaderUI(nil)
    }
    
    func serialDeviceObserver(_ observer: SerialDeviceObserver, didAttach attachedPorts: Set<ORSSerialPort>) {
        if attachedPorts.isEmpty == false {
            self.productInfoViewController?.readProductInfo(self)
            self.appDelegate?.cartInfoController.readHeader(self)
        }
    }
}

extension SerialDeviceViewController {
    
}

final class GBxCartViewController: SerialDeviceViewController<GBxCart> {
}
