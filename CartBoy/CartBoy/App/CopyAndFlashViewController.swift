import Cocoa
import Gibby
import CartKit

class CopyAndFlashViewController: ContextViewController {
    @IBOutlet weak var readProgressBar: NSProgressIndicator!
    @IBOutlet weak var writeProgressBar: NSProgressIndicator!
    @IBOutlet weak var spinnerProgressBar: NSProgressIndicator!
    @IBOutlet weak var statusTextField: NSTextField!
    @IBOutlet weak var statusView: NSView!
    
    private func displaySavePanel<Cartridge>(forCartridge cartridge: Cartridge,
                                                         _ callback: @escaping ((URL?) -> ())) where Cartridge: Gibby.Cartridge
    {
        DispatchQueue.main.async {
            let savePanel = NSSavePanel()
            savePanel.nameFieldStringValue = "\(cartridge.header.title).\(cartridge.fileExtension)"
            self.context.display(savePanel: savePanel) { response in
                guard let url = savePanel.url, case .OK = response else {
                    callback(nil)
                    return
                }
                callback(url)
            }
        }
    }

    @IBAction func read(_ sender: Any?) {
        GBxCart.open { serialDevice in
            switch serialDevice.readClassicCartridge(progress: {
                self.readProgressBar.doubleValue = $0.fractionCompleted
            }) {
            case .success(let cartridge):
                self.displaySavePanel(forCartridge: cartridge) { url in
                    guard let url = url else {
                        return
                    }
                    do {
                        try cartridge.write(to: url)
                    } catch {
                        self.context.display(error: error, in: self)
                    }
                }
            case .failure(let error):
                self.context.display(error: error, in: self)
            }
        }
    }
    
    @IBAction func write(_ sender: Any?) {
        guard let window = NSApp.mainWindow else {
            return
        }
        let openPanel = NSOpenPanel()
        openPanel.beginSheetModal(for: window) {
            guard case .OK = $0, let url = openPanel.url else {
                return
            }
            
            self.statusView.isHidden = false
            self.statusTextField.stringValue = "Erasing..."
            self.spinnerProgressBar.isHidden = false
            self.spinnerProgressBar.startAnimation(sender)
            
            GBxCart.open { serialDevice in
                let loadFile = Result {
                    try FlashCartridge<AM29F016B>(url: url)
                }
                let performFlash = serialDevice
                    .erase(flashCartridge: AM29F016B.self)
                    .flash(cartridge: loadFile, progress: { progress in
                        if self.statusTextField.stringValue != "Flashing..." {
                            self.statusTextField.stringValue = "Flashing..."
                            self.spinnerProgressBar.isHidden = true
                            self.spinnerProgressBar.stopAnimation(sender)
                        }
                        self.writeProgressBar.doubleValue = progress.fractionCompleted
                    })
                switch performFlash {
                case .success:
                    DispatchQueue.main.sync {
                        self.statusView.isHidden = true
                        self.context.update(progressBar: self.writeProgressBar, with: 0)
                        
                        // FIXME -- remove this hard-coded requirement
                        if let appDelegate = NSApp.delegate as? AppDelegate,
                            let cartInfo = appDelegate.cartInfoController
                        {
                            cartInfo.readHeader(sender)
                        }
                    }
                case .failure(let error):
                    self.context.display(error: error, in: self)
                }
            }
        }
    }
}
