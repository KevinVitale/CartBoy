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
    
    @IBAction func clearProductInfo(_ sender: Any?) {
        DispatchQueue.global().async {
            try! self.updateProductInfoResult().get()
        }
    }
    
    @IBAction func readProductInfo(_ sender: Any?) {
        DispatchQueue.global(qos: .userInitiated).async(flags: .barrier) {
            switch self.updateProductInfoResult()
                .flatMap({ _       in SerialDevice<GBxCart>.connect().voltage() })
                .flatMap({ voltage in SerialDevice<GBxCart>.connect().version().map { ($0, voltage.rawValue) } })
                .flatMap({ self.updateProductInfoResult(firmware: $0.0, voltage: $0.1, website: "insideGadgets.com") })
            {
            case .success(): (/* no-op */)
            case .failure(let error):
                self.context.display(error: error, in: self)
                self.clearProductInfo(nil)
            }
        }
    }
}
