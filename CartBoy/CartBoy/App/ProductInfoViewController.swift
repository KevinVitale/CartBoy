import Cocoa
import Gibby
import CartKit

class ProductInfoViewController: ContextViewController {
    @IBOutlet weak var firmwareTextField :NSTextField!
    @IBOutlet weak var voltageTextField  :NSTextField!
    @IBOutlet weak var websiteTextField  :NSTextField!
    
    override func prepare(for segue: NSStoryboardSegue, sender: Any?) {
        super.prepare(for: segue, sender: sender)
        guard let contentViewController = segue.destinationController as? GBxCartViewController
            , let appDelegate           = NSApp.delegate as? AppDelegate
            else {
                fatalError()
        }
        contentViewController.setup(with: appDelegate, inside: self)
    }
    
    override func viewDidLoad() {
        super.viewDidLoad()
        self.voltageTextField.stringValue = ""
        self.firmwareTextField.stringValue = ""
        self.websiteTextField.stringValue = ""
    }
    
    private func updateProductInfoResult(firmware: String = "", voltage: String = "", website: String = "") -> Result<(), Error> {
        return Result {
            DispatchQueue.main.sync {
                self.firmwareTextField.stringValue = firmware
                self.voltageTextField.stringValue = voltage
                self.websiteTextField.stringValue = website
            }
        }
    }
    
    @IBAction func clearProductInfo(_ sender: Any?) {
        DispatchQueue.global().async {
            try! self.updateProductInfoResult().get()
        }
    }
    
    @IBAction func readProductInfo(_ sender: Any?) {
        GBxCart.open { serialDevice in
            switch serialDevice
                .readVoltage()
                .flatMap({ voltage in
                    serialDevice.readPCBVersion().map { (voltage, $0) }
                }) {
            case .success(let voltage?, let version):
                try? self.updateProductInfoResult(
                    firmware :"\(version)",
                    voltage  :voltage.debugDescription,
                    website  :"insideGadgets.com"
                ).get()
            case .failure(let error):
                self.context.display(error: error, in: self)
                self.clearProductInfo(nil)
            default: ()
            }
        }
    }
}
