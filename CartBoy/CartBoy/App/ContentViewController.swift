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
        self.context.perform {
            let result = Result<GameboyClassic.Cartridge, Error> {
                let controller = try insideGadgetsController<GameboyClassic>()
                return try await { controller.readCartridge(progress: { self.context.update(progressBar: self.readProgressBar, with: $0) }, $0) }
            }
            
            switch result {
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
            
            self.context.perform {
                let result = Result<(), Error> {
                    let controller = try insideGadgetsController<GameboyClassic>()
                    DispatchQueue.main.sync {
                        self.statusView.isHidden = false
                        self.statusTextField.stringValue = "Erasing..."
                        self.spinnerProgressBar.isHidden = false
                        self.spinnerProgressBar.startAnimation(sender)
                    }
                    let _ /*write*/= try await { controller.write(flashCartridge, progress: { value in
                        if self.statusTextField.stringValue != "Flashing..." {
                            self.statusTextField.stringValue = "Flashing..."
                            self.spinnerProgressBar.isHidden = true
                            self.spinnerProgressBar.stopAnimation(sender)
                        }
                        self.context.update(progressBar: self.writeProgressBar, with: value)
                    }, $0) }
                    DispatchQueue.main.sync {
                        self.statusView.isHidden = true
                    }
                    if let appDelegate = NSApp.delegate as? AppDelegate, let cartInfo = appDelegate.cartInfoController {
                        cartInfo.readHeader(sender)
                    }
                    return ()
                }

                switch result {
                case .success: ()
                case .failure(let error):
                    print(error)
                    self.context.display(error: error, in: self)
                }
            }
        }
    }
}
