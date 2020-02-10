import AppKit
import Gibby
import CartKit

class CartInfoViewController: ContextViewController {
    @IBOutlet weak var saveActionContainerView: NSView!
    @IBOutlet weak var gridView: NSGridView!
    @IBOutlet weak var saveDataProgressBar: NSProgressIndicator!
    @IBOutlet weak var saveActionsStackView: NSStackView!
    @IBOutlet weak var saveNotSupportedStackView: NSStackView!
    
    private var clearGridViewDisplay: Result<(), Error> {
        return Result {
            DispatchQueue.main.sync {
                guard let gridView = self.gridView else {
                    return
                }
                for row in 0..<gridView.numberOfRows {
                    if let textField = gridView.column(at: 1).cell(at: row).contentView as? NSTextField {
                        textField.stringValue = ""
                    }
                }
            }
        }
    }
    
    private var showSaveProgressBar: Result<(),Error> {
        DispatchQueue.main.sync {
            Result { self.saveDataProgressBar.isHidden = false }
        }
    }
    
    private var hideSaveProgressBar: Result<(),Error> {
        DispatchQueue.main.sync {
            Result {
                self.saveDataProgressBar.isHidden = true
                self.saveDataProgressBar.doubleValue = 0.0
            }
        }
    }

    private func updateClassicSaveUI<Header: Gibby.Header>(with header: Header) -> Result<Header, Error> where Header.Platform == GameboyClassic {
        DispatchQueue.main.sync {
            Result {
                if header.configuration.hardware.contains(.ram) {
                    self.saveNotSupportedStackView?.isHidden = true
                    self.saveActionsStackView?.isHidden = false
                } else {
                    self.saveNotSupportedStackView?.isHidden = false
                    self.saveActionsStackView?.isHidden = true
                    self.saveDataProgressBar?.isHidden = true
                }
                return header
            }
        }
    }
    
    private func updateClassicHeaderUI<Header: Gibby.Header>(with header: Header) -> Result<Header, Error> where Header.Platform == GameboyClassic {
        DispatchQueue.main.sync {
            Result {
                func set(string value: String, rowIndex: Int) {
                    DispatchQueue.main.async {
                        if let textField = self.gridView.cell(atColumnIndex: 1, rowIndex: rowIndex).contentView as? NSTextField {
                            textField.stringValue = value
                        }
                    }
                }
                
                let byteCountFormatter = ByteCountFormatter()
                
                byteCountFormatter.allowedUnits = .useBytes
                let kilobyteString = byteCountFormatter.string(fromByteCount: Int64(header.romSize))
                
                byteCountFormatter.allowedUnits = .useMB
                let megabyteString = byteCountFormatter.string(fromByteCount: Int64(header.romSize))
                
                set(string: header.title, rowIndex: 0)
                set(string: "\(header.configuration)", rowIndex: 1)
                set(string: "\(kilobyteString) (\(megabyteString))", rowIndex: 2)
                set(string: "\(header.region)".uppercased(), rowIndex: 3)
                set(string: "\(header.superGameboySupported)".uppercased(), rowIndex: 4)
                
                return header
            }
        }
    }
    
    override func awakeFromNib() {
        super.awakeFromNib()
        
        if let appDelegate = NSApp.delegate as? AppDelegate {
            appDelegate.cartInfoController = self
        }
        self.clearHeaderUI(nil)
    }

    @IBAction func clearHeaderUI(_ sender: Any?) {
        DispatchQueue.global(qos: .userInitiated).async(flags: .barrier) {
            let emptyHeaderData = Data(count: GameboyClassic.headerRange.count)
            let emptyHeader     = GameboyClassic.Header(bytes: emptyHeaderData)
            
            switch self
                .clearGridViewDisplay
                .flatMap({ self.updateClassicSaveUI(with: emptyHeader) })
            {
            default: (/* no-op */)
            }
        }
    }
    
    @IBAction func readHeader(_ sender: Any?) {
        SerialDeviceSession<GBxCart>.open { serialDevice in
            switch serialDevice
                .readHeader(forPlatform: GameboyClassic.self)
                .flatMap({ self.updateClassicHeaderUI(with: $0) })
                .flatMap({ self.updateClassicSaveUI(with: $0) })
            {
            case .success: (/* no-op */)
            case .failure(let error):
                self.context.display(error: error, in: self)
                self.clearHeaderUI(sender)
            }
        }
    }
    
    @IBAction func readSaveData(_ sender: Any?) {
        SerialDeviceSession<GBxCart>.open { serialDevice in
            switch self.showSaveProgressBar
                .flatMap({
                    serialDevice.readClassicSaveData {
                        self.saveDataProgressBar.doubleValue = $0.fractionCompleted
                    }
                    .flatMap { data in
                        self.hideSaveProgressBar.map { data }
                    }
                })
                .flatMap({ data in
                    serialDevice
                        .readHeader(forPlatform: GameboyClassic.self)
                        .map { header in
                            (header.title + ".sav", data)
                    }
                })
            {
            case .success(let fileName, let saveData):
                DispatchQueue.main.async {
                    // Create the 'Save Panel' ---------------------------------
                    let savePanel: NSSavePanel = {
                        let savePanel = NSSavePanel()
                        savePanel.nameFieldStringValue = fileName
                        return savePanel
                    }()
                    // Dispaly it; get result ----------------------------------
                    self.context.display(savePanel: savePanel) { response in
                        guard let url = savePanel.url,
                            case .OK = response else
                        {
                            return /* no-op */
                        }
                        
                        do    { try saveData.write(to: url) }
                        catch { self.context.display(error: error, in: self) }
                    }
                    // ---------------------------------------------------------
                }
            case .failure(let error):
                self.context.display(error: error, in: self)
            }
        }
    }
    
    private func selectSaveFile(openPanelIn window: NSWindow, _ callback: @escaping (Data?) -> ()) {
        let openPanel = NSOpenPanel()
        openPanel.beginSheetModal(for: window) {
            guard case .OK = $0, let url = openPanel.url, let data = try? Data(contentsOf: url) else {
                callback(nil)
                return
            }
            
            callback(data)
        }
    }
    
    @IBAction func writeSaveData(_ sender: Any?) {
        guard let window = NSApp.mainWindow else {
            return
        }
        self.selectSaveFile(openPanelIn: window) { data in
            guard let data = data else {
                return
            }
            
            SerialDeviceSession<GBxCart>.open { serialDevice in
                switch self
                    .showSaveProgressBar
                    .flatMap({
                        serialDevice.restoreClassicSaveData(data, progress: {
                            self.saveDataProgressBar.doubleValue = $0.fractionCompleted
                        })
                    })
                    .flatMap({ _ in self.hideSaveProgressBar })
                {
                case .success: (/* no-op */)
                case .failure(let error): self.context.display(error: error, in: self)
                }
            }
        }
    }
    
    @IBAction func eraseSaveData(_ sender: Any?) {
        guard let window = NSApp.mainWindow else {
            return
        }
        
        let alert = NSAlert()
        alert.messageText = "Erasing Save Data"
        alert.informativeText = "If save data is erased, any game progress will be reset. Consider backing up save data first, if necessary."
        alert.addButton(withTitle: "Erase")
        alert.addButton(withTitle: "Cancel")
        alert.alertStyle = .warning
        
        alert.beginSheetModal(for: window) {
            guard $0 == .alertFirstButtonReturn else {
                return
            }
            
            SerialDeviceSession<GBxCart>.open { serialDevice in
                switch self
                    .showSaveProgressBar
                    .flatMap({
                        serialDevice.deleteClassicSaveData {
                            self.saveDataProgressBar.doubleValue = $0.fractionCompleted
                        }
                    })
                    .flatMap({ _ in self.hideSaveProgressBar })
                {
                case .success(): (/* no-op */)
                case .failure(let error): self.context.display(error: error, in: self)
                }
            }
        }
    }
}

