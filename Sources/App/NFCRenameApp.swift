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
        WindowObserverView()
    }

    func updateNSView(_ nsView: NSView, context: Context) {}
}

final class WindowObserverView: NSView {
    private static let windowFrameKey = "windowFrame"
    private static let fallbackWindowSize = NSSize(width: 160, height: 160)

    private var moveObserver: NSObjectProtocol?
    private var screenObserver: NSObjectProtocol?
    private weak var configuredWindow: NSWindow?

    override func viewDidMoveToWindow() {
        super.viewDidMoveToWindow()

        guard let window else { return }
        configure(window)
    }

    deinit {
        stopObserving()
    }

    private func configure(_ window: NSWindow) {
        guard configuredWindow !== window else { return }

        stopObserving()
        configuredWindow = window

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
        window.isRestorable = false

        restoreReachableFrame(for: window)

        DispatchQueue.main.async { [weak self, weak window] in
            guard let self, let window, self.configuredWindow === window else { return }
            self.restoreReachableFrame(for: window)
            self.startObserving(window)
        }
    }

    private func startObserving(_ window: NSWindow) {
        moveObserver = NotificationCenter.default.addObserver(
            forName: NSWindow.didMoveNotification,
            object: window,
            queue: .main
        ) { [weak self, weak window] _ in
            guard let self, let window else { return }
            self.saveFrame(window.frame)
        }

        screenObserver = NotificationCenter.default.addObserver(
            forName: NSApplication.didChangeScreenParametersNotification,
            object: nil,
            queue: .main
        ) { [weak self, weak window] _ in
            guard let self, let window else { return }
            self.restoreReachableFrame(for: window, using: window.frame)
        }
    }

    private func stopObserving() {
        if let moveObserver {
            NotificationCenter.default.removeObserver(moveObserver)
            self.moveObserver = nil
        }

        if let screenObserver {
            NotificationCenter.default.removeObserver(screenObserver)
            self.screenObserver = nil
        }
    }

    private func restoreReachableFrame(for window: NSWindow, using preferredFrame: NSRect? = nil) {
        let fallbackSize = Self.validSize(window.frame.size) ?? Self.fallbackWindowSize
        let frame = preferredFrame ?? Self.savedFrame() ?? window.frame
        let reachableFrame = Self.reachableFrame(
            for: frame,
            fallbackSize: fallbackSize,
            preferredScreen: window.screen
        )

        window.setFrame(reachableFrame, display: true)
        saveFrame(reachableFrame)
    }

    private func saveFrame(_ frame: NSRect) {
        UserDefaults.standard.set(NSStringFromRect(frame), forKey: Self.windowFrameKey)
    }

    private static func savedFrame() -> NSRect? {
        guard let data = UserDefaults.standard.string(forKey: windowFrameKey) else { return nil }

        let frame = NSRectFromString(data)
        guard validSize(frame.size) != nil,
              frame.origin.x.isFinite,
              frame.origin.y.isFinite else {
            return nil
        }

        return frame
    }

    private static func reachableFrame(
        for frame: NSRect,
        fallbackSize: NSSize,
        preferredScreen: NSScreen?
    ) -> NSRect {
        let visibleFrames = NSScreen.screens
            .map(\.visibleFrame)
            .filter { !$0.isEmpty }

        guard !visibleFrames.isEmpty else { return frame }

        let frameSize = validSize(frame.size) ?? fallbackSize
        let sizedFrame = NSRect(origin: frame.origin, size: frameSize)

        if let visibleFrame = bestIntersectingVisibleFrame(for: sizedFrame, in: visibleFrames) {
            return clamp(sizedFrame, to: visibleFrame)
        }

        let fallbackVisibleFrame = preferredScreen?.visibleFrame.isEmpty == false
            ? preferredScreen!.visibleFrame
            : (NSScreen.main?.visibleFrame ?? visibleFrames[0])

        return centeredFrame(size: frameSize, in: fallbackVisibleFrame)
    }

    private static func bestIntersectingVisibleFrame(
        for frame: NSRect,
        in visibleFrames: [NSRect]
    ) -> NSRect? {
        visibleFrames
            .map { visibleFrame in
                (visibleFrame, intersectionArea(frame, visibleFrame))
            }
            .filter { $0.1 > 0 }
            .max { $0.1 < $1.1 }?
            .0
    }

    private static func clamp(_ frame: NSRect, to visibleFrame: NSRect) -> NSRect {
        let width = min(frame.width, visibleFrame.width)
        let height = min(frame.height, visibleFrame.height)
        let minX = visibleFrame.minX
        let maxX = visibleFrame.maxX - width
        let minY = visibleFrame.minY
        let maxY = visibleFrame.maxY - height

        return NSRect(
            x: min(max(frame.minX, minX), maxX),
            y: min(max(frame.minY, minY), maxY),
            width: width,
            height: height
        )
    }

    private static func centeredFrame(size: NSSize, in visibleFrame: NSRect) -> NSRect {
        let width = min(size.width, visibleFrame.width)
        let height = min(size.height, visibleFrame.height)

        return NSRect(
            x: visibleFrame.midX - width / 2,
            y: visibleFrame.midY - height / 2,
            width: width,
            height: height
        )
    }

    private static func intersectionArea(_ lhs: NSRect, _ rhs: NSRect) -> CGFloat {
        let intersection = lhs.intersection(rhs)
        guard !intersection.isNull else { return 0 }
        return max(0, intersection.width) * max(0, intersection.height)
    }

    private static func validSize(_ size: NSSize) -> NSSize? {
        guard size.width.isFinite,
              size.height.isFinite,
              size.width > 0,
              size.height > 0 else {
            return nil
        }

        return size
    }
}
