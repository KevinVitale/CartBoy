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
    @IBAction func readHeader(_ sender: Any?) {
        print(#function)
        do {
            let reader = try InsideGadgetsCartridgeController.reader(for: GameboyClassic.Cartridge.self)
            reader.readHeader {
                if let header = $0 {
                    print(header)
                }
            }
        } catch {
            print(error)
        }
    }
}
