import Cocoa
import ORSSerial
import Gibby
import CartKit

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
