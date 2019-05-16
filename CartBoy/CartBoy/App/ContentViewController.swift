import Cocoa
import Gibby
import CartKit

class ContentViewController: ContextViewController, NSTabViewDelegate {
    @IBOutlet weak var progressBar: NSProgressIndicator!

    func tabView(_ tabView: NSTabView, didSelect tabViewItem: NSTabViewItem?) {
    }
    
    @IBAction func read(_ sender: Any?) {
        self.context.perform {
            let result = Result<GameboyClassic.Cartridge, Error> {
                let controller = try insideGadgetsController<GameboyClassic>()
                return try await { controller.readCartridge(progress: { self.context.update(progressBar: self.progressBar, with: $0) }, $0) }
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
}
