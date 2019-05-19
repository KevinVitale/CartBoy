import Cocoa
import Gibby
import CartKit

class ProductInfoViewController: ContextViewController {
    @IBOutlet weak var firmwareTextField: NSTextField!
    @IBOutlet weak var voltageTextField: NSTextField!
    @IBOutlet weak var websiteTextField: NSTextField!
    
    override func awakeFromNib() {
        super.awakeFromNib()
        
        if let appDelegate = NSApp.delegate as? AppDelegate {
            appDelegate.productInfoController = self
        }
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
    
    @IBAction func readProductInfo(_ sender: Any?) {
        insideGadgetsController.perform { controller in
            switch controller
                .flatMap({ controller in .success(Voltage.high) /* controller.voltage() */ })
                .flatMap({ self.updateProductInfoResult(voltage: $0.rawValue, website: "www.insideGadgets.com") })
            {
            case .success: ()
            case .failure(let error):
                self.context.display(error: error, in: self)
                try! self.updateProductInfoResult().get()
            }
        }
    }
}
