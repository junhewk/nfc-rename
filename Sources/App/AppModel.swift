import AppKit
import Combine

/// Shared state for the drop zone, the Finder Services menu, and the menu bar commands.
final class AppModel: ObservableObject {
    static let shared = AppModel()
    static let recursiveKey = "recursive"
    static let showsDropZoneKey = "showsDropZone"

    enum Status: Equatable {
        case idle
        case working
        case done(Outcome)
        case checked(CheckResult)
    }

    struct CheckResult: Equatable {
        let urls: [URL]
        let nfdNames: [String]
        let total: Int

        var message: String {
            nfdNames.isEmpty ? "모두 NFC" : "NFD \(nfdNames.count)개"
        }

        var details: String? {
            guard !nfdNames.isEmpty else { return nil }
            let shown = nfdNames.prefix(10).joined(separator: "\n")
            return nfdNames.count > 10 ? shown + "\n… 외 \(nfdNames.count - 10)개" : shown
        }
    }

    struct Outcome: Equatable {
        let renamed: Int
        let skipped: Int
        let failed: Int
        let failureDetails: String?

        var message: String {
            switch (renamed, failed) {
            case (0, 0): return "이미 NFC"
            case (_, 0): return "\(renamed)개 변환"
            case (0, _): return "\(failed)개 실패"
            default: return "\(renamed)개 변환, \(failed)개 실패"
            }
        }
    }

    @Published private(set) var status: Status = .idle

    /// The floating drop zone is optional — everything is also in the menu bar.
    @Published var showsDropZone: Bool {
        didSet { UserDefaults.standard.set(showsDropZone, forKey: Self.showsDropZoneKey) }
    }

    private let converter = NFCConverter()
    private let queue = DispatchQueue(label: "nfc-rename.convert", qos: .userInitiated)
    private var resetWork: DispatchWorkItem?

    private init() {
        UserDefaults.standard.register(defaults: [Self.recursiveKey: true, Self.showsDropZoneKey: true])
        showsDropZone = UserDefaults.standard.bool(forKey: Self.showsDropZoneKey)
    }

    func convert(_ urls: [URL]) {
        let fileURLs = urls.filter(\.isFileURL)
        guard !fileURLs.isEmpty else { return }

        resetWork?.cancel()
        status = .working

        let recursive = UserDefaults.standard.bool(forKey: Self.recursiveKey)

        // Off the main thread — large folders would otherwise freeze the drop zone
        queue.async { [converter] in
            let summary = converter.convert(urls: fileURLs, recursive: recursive)
            let details = summary.results
                .compactMap { result in
                    result.error.map { "\((result.originalPath as NSString).lastPathComponent): \($0)" }
                }
                .prefix(5)
                .joined(separator: "\n")

            let outcome = Outcome(
                renamed: summary.renamed,
                skipped: summary.skipped,
                failed: summary.failed,
                failureDetails: details.isEmpty ? nil : details
            )

            DispatchQueue.main.async {
                self.finish(with: outcome)
            }
        }
    }

    /// Reports which filenames are NFD without renaming anything.
    func check(_ urls: [URL]) {
        let fileURLs = urls.filter(\.isFileURL)
        guard !fileURLs.isEmpty else { return }

        resetWork?.cancel()
        status = .working

        let recursive = UserDefaults.standard.bool(forKey: Self.recursiveKey)

        queue.async { [converter] in
            let found = converter.findNFD(urls: fileURLs, recursive: recursive)
            let result = CheckResult(
                urls: fileURLs,
                nfdNames: found.nfd.map { ($0 as NSString).lastPathComponent },
                total: found.total
            )

            DispatchQueue.main.async {
                self.status = .checked(result)
                self.scheduleReset(after: result.nfdNames.isEmpty ? 3 : 10)
            }
        }
    }

    /// Converts the items from the last check, if it found any NFD names.
    func convertChecked() {
        guard case .checked(let result) = status, !result.nfdNames.isEmpty else { return }
        convert(result.urls)
    }

    func chooseFiles(checkOnly: Bool = false) {
        let panel = NSOpenPanel()
        panel.title = checkOnly ? "NFD 여부를 확인할 항목 선택" : "NFC로 변환할 항목 선택"
        panel.prompt = checkOnly ? "확인" : "변환"
        panel.canChooseFiles = true
        panel.canChooseDirectories = true
        panel.allowsMultipleSelection = true
        // The drop zone floats above normal windows; keep the panel above it
        panel.level = .modalPanel

        NSApp.activate()
        guard panel.runModal() == .OK else { return }
        if checkOnly {
            check(panel.urls)
        } else {
            convert(panel.urls)
        }
    }

    private func finish(with outcome: Outcome) {
        status = .done(outcome)
        scheduleReset(after: outcome.failed > 0 ? 6 : 3)
    }

    private func scheduleReset(after seconds: TimeInterval) {
        resetWork?.cancel()
        let work = DispatchWorkItem { [weak self] in
            self?.status = .idle
        }
        resetWork = work
        DispatchQueue.main.asyncAfter(deadline: .now() + seconds, execute: work)
    }
}
