import AppKit
import Combine
import ServiceManagement

/// Menu bar icon: a menu with every action, and a drop target for files.
final class StatusBarController: NSObject, NSMenuDelegate, NSWindowDelegate {
    private static let idleSymbol = "arrow.triangle.2.circlepath"

    private let model = AppModel.shared
    private let statusItem = NSStatusBar.system.statusItem(withLength: NSStatusItem.squareLength)
    private var statusObserver: AnyCancellable?

    /// The most recent result, kept for the menu after the drop zone has gone back to idle.
    private var lastStatus: AppModel.Status?

    override init() {
        super.init()

        let menu = NSMenu()
        menu.delegate = self
        statusItem.menu = menu

        if let button = statusItem.button {
            button.toolTip = "NFCRename — 파일을 올려 놓으면 NFC로 변환, ⌥ 누르고 놓으면 확인만"
            // NSWindow forwards dragging-destination calls to its delegate
            button.window?.registerForDraggedTypes([.fileURL])
            button.window?.delegate = self
        }

        statusObserver = model.$status.sink { [weak self] status in
            self?.update(for: status)
        }
    }

    // MARK: - Icon

    private func update(for status: AppModel.Status) {
        switch status {
        case .idle:
            setSymbol(Self.idleSymbol)
        case .working:
            setSymbol("ellipsis.circle")
        case .done(let outcome):
            lastStatus = status
            setSymbol(outcome.failed > 0 ? "exclamationmark.triangle" : "checkmark.circle")
        case .checked(let result):
            lastStatus = status
            setSymbol(result.nfdNames.isEmpty ? "checkmark.seal" : "exclamationmark.circle")
        }
    }

    private func setSymbol(_ name: String) {
        let image = NSImage(systemSymbolName: name, accessibilityDescription: "NFCRename")
        image?.isTemplate = true
        statusItem.button?.image = image
    }

    // MARK: - Menu

    func menuNeedsUpdate(_ menu: NSMenu) {
        menu.removeAllItems()

        if let lastStatus {
            addResultItems(for: lastStatus, to: menu)
            menu.addItem(.separator())
        }

        menu.addItem(item("파일 선택해서 변환…", #selector(chooseToConvert), key: "o"))
        let check = item("NFD 여부 확인…", #selector(chooseToCheck), key: "o")
        check.keyEquivalentModifierMask = [.command, .option]
        menu.addItem(check)

        menu.addItem(.separator())

        let recursive = item("하위 폴더 포함", #selector(toggleRecursive))
        recursive.state = UserDefaults.standard.bool(forKey: AppModel.recursiveKey) ? .on : .off
        menu.addItem(recursive)

        let dropZone = item("드롭 영역 표시", #selector(toggleDropZone))
        dropZone.state = model.showsDropZone ? .on : .off
        menu.addItem(dropZone)

        let login = item("로그인 시 열기", #selector(toggleLaunchAtLogin))
        login.state = SMAppService.mainApp.status == .enabled ? .on : .off
        menu.addItem(login)

        menu.addItem(.separator())
        menu.addItem(item("NFCRename 종료", #selector(quit), key: "q"))
    }

    private func addResultItems(for status: AppModel.Status, to menu: NSMenu) {
        switch status {
        case .done(let outcome):
            menu.addItem(infoItem("최근: \(outcome.message)", details: outcome.failureDetails))
        case .checked(let result):
            menu.addItem(infoItem(
                "최근 확인: \(result.message) (\(result.total)개 중)",
                details: result.details
            ))
            if !result.nfdNames.isEmpty {
                let convert = item("NFD \(result.nfdNames.count)개 NFC로 변환", #selector(convertLastChecked))
                convert.representedObject = result.urls
                menu.addItem(convert)
            }
        case .idle, .working:
            break
        }
    }

    private func item(_ title: String, _ action: Selector, key: String = "") -> NSMenuItem {
        let item = NSMenuItem(title: title, action: action, keyEquivalent: key)
        item.target = self
        return item
    }

    private func infoItem(_ title: String, details: String?) -> NSMenuItem {
        let item = NSMenuItem(title: title, action: nil, keyEquivalent: "")
        item.isEnabled = false
        item.toolTip = details
        return item
    }

    // MARK: - Actions

    @objc private func chooseToConvert() {
        model.chooseFiles()
    }

    @objc private func chooseToCheck() {
        model.chooseFiles(checkOnly: true)
    }

    @objc private func convertLastChecked(_ sender: NSMenuItem) {
        guard let urls = sender.representedObject as? [URL] else { return }
        model.convert(urls)
    }

    @objc private func toggleRecursive() {
        let defaults = UserDefaults.standard
        defaults.set(!defaults.bool(forKey: AppModel.recursiveKey), forKey: AppModel.recursiveKey)
    }

    @objc private func toggleDropZone() {
        model.showsDropZone.toggle()
    }

    @objc private func toggleLaunchAtLogin() {
        do {
            if SMAppService.mainApp.status == .enabled {
                try SMAppService.mainApp.unregister()
            } else {
                try SMAppService.mainApp.register()
            }
        } catch {
            NSAlert(error: error).runModal()
        }
    }

    @objc private func quit() {
        NSApp.terminate(nil)
    }

    // MARK: - Dropping files on the icon

    func draggingEntered(_ sender: NSDraggingInfo) -> NSDragOperation {
        guard !fileURLs(from: sender).isEmpty else { return [] }
        statusItem.button?.highlight(true)
        return .copy
    }

    func draggingExited(_ sender: NSDraggingInfo?) {
        statusItem.button?.highlight(false)
    }

    func performDragOperation(_ sender: NSDraggingInfo) -> Bool {
        statusItem.button?.highlight(false)

        let urls = fileURLs(from: sender)
        guard !urls.isEmpty else { return false }

        // Same as the drop zone: holding ⌥ only checks
        if NSEvent.modifierFlags.contains(.option) {
            model.check(urls)
        } else {
            model.convert(urls)
        }
        return true
    }

    private func fileURLs(from info: NSDraggingInfo) -> [URL] {
        info.draggingPasteboard.readObjects(
            forClasses: [NSURL.self],
            options: [.urlReadingFileURLsOnly: true]
        ) as? [URL] ?? []
    }
}
