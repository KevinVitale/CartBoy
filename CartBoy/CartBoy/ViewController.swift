import Cocoa
import ORSSerial
import Gibby
import CartKit


class CartInfoController: NSObject {
    private var _queue: DispatchQueue!
    @IBOutlet weak var viewController: NSViewController!
    
    override func awakeFromNib() {
        super.awakeFromNib()
        _queue = DispatchQueue(label: "com.cartboy.controller.cartridge.info")
    }
    
    @IBAction func readHeader(_ sender: Any?) {
        _queue.async(flags: .barrier) {
            do {
                throw CocoaError(.featureUnsupported)
            }
            catch {
                DispatchQueue.main.async {
                    self.viewController.presentError(error
                        , modalFor: NSApp.mainWindow!
                        , delegate: nil
                        , didPresent: nil
                        , contextInfo: nil
                    )
                }
            }
        }
    }
}


class ViewController: NSViewController {
    override func viewDidLoad() {
        super.viewDidLoad()
    }

    override var representedObject: Any? {
        didSet {
        }
    }
}

class ContentViewController: NSViewController {
    @IBOutlet weak var cartridgeProgressBar: NSProgressIndicator!
    
    @IBAction func readHeader(_ sender: Any?) {
        print(#function)
        do {
            let reader = try InsideGadgetsCartridgeController.reader(for: GameboyClassic.Cartridge.self).get()
            reader.header {
                switch $0 {
                case .failure(let error):
                    print(error)
                case .success(let header):
                    print(header)
                }
            }
        } catch {
            print(error)
        }
    }
    
    @IBAction func readCartridge(_ sender: Any?) {
        print(#function)
        do {
            let reader = try InsideGadgetsCartridgeController.reader(for: GameboyClassic.Cartridge.self).get()
            reader.cartridge(progress: { [weak self] in
                self?.cartridgeProgressBar.doubleValue = $0
            }) {
                switch $0 {
                case .failure(let error):
                    print(error)
                case .success(let cartridge):
                    print(cartridge)
                    print(cartridge.header)
                }
            }
        } catch {
            print(error)
        }
    }
}
