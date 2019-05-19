import Cocoa
import Gibby
import CartKit

class ContentViewController: ContextViewController {
    @IBOutlet weak var readProgressBar: NSProgressIndicator!
    @IBOutlet weak var writeProgressBar: NSProgressIndicator!
    @IBOutlet weak var spinnerProgressBar: NSProgressIndicator!
    @IBOutlet weak var statusTextField: NSTextField!
    @IBOutlet weak var statusView: NSView!

    @IBAction func read(_ sender: Any?) {
        insideGadgetsController.perform { controller in
            switch controller.flatMap({
                $0.cartridge(for: GameboyClassic.self, progress: {
                    self.context.update(progressBar: self.readProgressBar, with: $0)
                })
            })
            {
            case .success(let cartridge):
                DispatchQueue.main.sync {
                    let savePanel = NSSavePanel()
                    savePanel.nameFieldStringValue = "\(cartridge.header.title).\(cartridge.fileExtension)"
                    self.context.display(savePanel: savePanel) { response in
                        guard let url = savePanel.url, case .OK = response else {
                            return
                        }
                        do {
                            try cartridge.write(to: url)
                        } catch {
                            self.context.display(error: error, in: self)
                        }
                    }
                }
            case .failure(let error): self.context.display(error: error, in: self)
            }
        }
    }
    
    @IBAction func write(_ sender: Any?) {
        guard let window = NSApp.mainWindow else {
            return
        }
        let openPanel = NSOpenPanel()
        openPanel.beginSheetModal(for: window) {
            guard case .OK = $0, let url = openPanel.url, let data = try? Data(contentsOf: url) else {
                return
            }
            
            let flashCartridge = AM29F016B(bytes: data)
            insideGadgetsController.perform { controller in
                DispatchQueue.main.sync {
                    self.statusView.isHidden = false
                    self.statusTextField.stringValue = "Erasing..."
                    self.spinnerProgressBar.isHidden = false
                    self.spinnerProgressBar.startAnimation(sender)
                }
                switch controller.flatMap({ controller in
                    controller.write(to: flashCartridge, progress: { amount in
                        if self.statusTextField.stringValue != "Flashing..." {
                            self.statusTextField.stringValue = "Flashing..."
                            self.spinnerProgressBar.isHidden = true
                            self.spinnerProgressBar.stopAnimation(sender)
                        }
                        self.context.update(progressBar: self.writeProgressBar, with: amount)
                    })
                }) {
                case .success: ()
                case .failure(let error):
                    self.context.display(error: error, in: self)
                }
                //--------------------------------------------------------------
                // Double-check these two 'finality' logic blocks...
                DispatchQueue.main.sync {
                    self.statusView.isHidden = true
                }
                if let appDelegate = NSApp.delegate as? AppDelegate, let cartInfo = appDelegate.cartInfoController {
                    cartInfo.readHeader(sender)
                }
            }
        }
    }
}
