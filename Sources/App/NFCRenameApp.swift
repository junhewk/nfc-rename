import SwiftUI

@main
struct NFCRenameApp: App {
    @NSApplicationDelegateAdaptor(AppDelegate.self) var appDelegate

    var body: some Scene {
        WindowGroup {
            DropZoneView()
                .background(WindowAccessor())
        }
        .windowStyle(.hiddenTitleBar)
        .defaultSize(width: 160, height: 160)
        .windowResizability(.contentSize)
    }
}

class AppDelegate: NSObject, NSApplicationDelegate {
    func applicationShouldTerminateAfterLastWindowClosed(_ sender: NSApplication) -> Bool {
        true
    }
}

struct WindowAccessor: NSViewRepresentable {
    func makeNSView(context: Context) -> NSView {
        let view = WindowObserverView()
        DispatchQueue.main.async {
            guard let window = view.window else { return }
            window.level = .floating
            window.isOpaque = false
            window.backgroundColor = .clear
            window.hasShadow = true
            window.isMovableByWindowBackground = true
            window.titlebarAppearsTransparent = true
            window.titleVisibility = .hidden
            window.styleMask.remove(.titled)
            window.styleMask.insert(.borderless)
            window.title = "NFCRename"

            // Restore saved position
            if let data = UserDefaults.standard.string(forKey: "windowFrame") {
                window.setFrame(NSRectFromString(data), display: true)
            }

            // Observe moves
            NotificationCenter.default.addObserver(
                forName: NSWindow.didMoveNotification,
                object: window,
                queue: .main
            ) { _ in
                UserDefaults.standard.set(NSStringFromRect(window.frame), forKey: "windowFrame")
            }
        }
        return view
    }

    func updateNSView(_ nsView: NSView, context: Context) {}
}

class WindowObserverView: NSView {
    override func viewDidMoveToWindow() {
        super.viewDidMoveToWindow()
    }
}
