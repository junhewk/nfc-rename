import SwiftUI
import UniformTypeIdentifiers

struct DropZoneView: View {
    @State private var isTargeted = false
    @State private var lastResult: String?
    @State private var showResult = false

    private let converter = NFCConverter()

    var body: some View {
        ZStack {
            RoundedRectangle(cornerRadius: 20)
                .fill(.ultraThinMaterial)

            RoundedRectangle(cornerRadius: 20)
                .strokeBorder(
                    isTargeted ? Color.accentColor : Color.secondary.opacity(0.3),
                    style: StrokeStyle(lineWidth: 2, dash: isTargeted ? [] : [8, 4])
                )

            VStack(spacing: 8) {
                Image(systemName: "arrow.triangle.2.circlepath")
                    .font(.system(size: 36, weight: .light))
                    .foregroundStyle(isTargeted ? Color.accentColor : .secondary)

                Text("NFD → NFC")
                    .font(.system(size: 13, weight: .medium, design: .rounded))
                    .foregroundStyle(.primary)

                if showResult, let lastResult {
                    Text(lastResult)
                        .font(.system(size: 11))
                        .foregroundStyle(.secondary)
                        .multilineTextAlignment(.center)
                        .transition(.opacity.combined(with: .move(edge: .bottom)))
                }
            }
            .padding(8)
        }
        .frame(width: 160, height: 160)
        .onDrop(of: [.fileURL], isTargeted: $isTargeted) { providers in
            handleDrop(providers)
            return true
        }
        .animation(.easeInOut(duration: 0.2), value: isTargeted)
        .animation(.easeInOut(duration: 0.3), value: showResult)
    }

    private func handleDrop(_ providers: [NSItemProvider]) {
        var urls: [URL] = []
        let group = DispatchGroup()

        for provider in providers {
            group.enter()
            provider.loadItem(forTypeIdentifier: UTType.fileURL.identifier, options: nil) { item, _ in
                defer { group.leave() }
                guard let data = item as? Data,
                      let url = URL(dataRepresentation: data, relativeTo: nil) else { return }
                urls.append(url)
            }
        }

        group.notify(queue: .main) {
            guard !urls.isEmpty else { return }

            let recursive = UserDefaults.standard.bool(forKey: "recursive")
            let summary = converter.convert(urls: urls, recursive: recursive)

            if summary.renamed > 0 {
                lastResult = "\(summary.renamed)개 변환"
                if summary.skipped > 0 {
                    lastResult! += ", \(summary.skipped)개 건너뜀"
                }
            } else {
                lastResult = "변환할 파일 없음"
            }

            if summary.failed > 0 {
                lastResult = "\(summary.failed)개 실패"
                if summary.renamed > 0 {
                    lastResult = "\(summary.renamed)개 변환, \(summary.failed)개 실패"
                }
            }

            showResult = true

            // Auto-hide result after 3 seconds
            DispatchQueue.main.asyncAfter(deadline: .now() + 3) {
                showResult = false
            }
        }
    }
}
