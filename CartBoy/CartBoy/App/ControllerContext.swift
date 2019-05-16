import Cocoa

class ControllerContext: NSObject {
    private let _queue: DispatchQueue
    
    required init(label: String = "com.cartboy.cartridge.controller") {
        self._queue = DispatchQueue(label: label)
        super.init()
    }
    
    func perform(_ block: @escaping () -> ()) {
        self._queue.async(flags: .barrier) {
            block()
        }
    }
    
    func update(progressBar: NSProgressIndicator?, with value: Double) {
        DispatchQueue.main.async {
            progressBar?.doubleValue = value
        }
    }
    
    func display(error: Error, in viewController: NSViewController) {
        DispatchQueue.main.async {
            guard let window = NSApp.mainWindow else {
                return
            }
            viewController.presentError(error
                , modalFor: window
                , delegate: nil
                , didPresent: nil
                , contextInfo: nil
            )
        }
    }
    
    func display(savePanel: NSSavePanel, in window: NSWindow? = NSApp.mainWindow, _ response: @escaping ((NSApplication.ModalResponse) -> ()) = { _ in }) {
        guard let window = window else { return }
        DispatchQueue.main.async {
            savePanel.beginSheetModal(for: window, completionHandler: response)
        }
    }
}
