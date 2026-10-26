import SwiftUI

struct DropZoneView: View {
    @ObservedObject private var model = AppModel.shared
    @AppStorage(AppModel.recursiveKey) private var recursive = true

    @State private var isTargeted = false
    @State private var isHovering = false

    var body: some View {
        ZStack {
            RoundedRectangle(cornerRadius: 20)
                .fill(.ultraThinMaterial)

            RoundedRectangle(cornerRadius: 20)
                .fill(Color.accentColor.opacity(isTargeted ? 0.12 : 0))

            RoundedRectangle(cornerRadius: 20)
                .strokeBorder(
                    isTargeted ? Color.accentColor : Color.secondary.opacity(0.3),
                    style: StrokeStyle(lineWidth: 2, dash: isTargeted ? [] : [8, 4])
                )

            VStack(spacing: 6) {
                statusIcon
                    .font(.system(size: 34, weight: .light))
                    .frame(height: 40)

                Text(title)
                    .font(.system(size: 13, weight: .medium, design: .rounded))
                    .foregroundStyle(.primary)

                Text(subtitle)
                    .font(.system(size: 11))
                    .foregroundStyle(.secondary)
                    .multilineTextAlignment(.center)
                    .lineLimit(2)
            }
            .padding(.horizontal, 10)
            .offset(y: -6)

            if isHovering && !isTargeted {
                controls
                    .transition(.opacity)
            }
        }
        .frame(width: 160, height: 160)
        .help(details ?? "")
        .dropDestination(for: URL.self) { urls, _ in
            // Holding ⌥ while dropping only checks — nothing is renamed
            if NSEvent.modifierFlags.contains(.option) {
                model.check(urls)
            } else {
                model.convert(urls)
            }
            return true
        } isTargeted: { isTargeted = $0 }
        .onHover { isHovering = $0 }
        .contextMenu {
            Button("파일 선택…") { model.chooseFiles() }
            Button("NFD 여부 확인…") { model.chooseFiles(checkOnly: true) }
            Toggle("하위 폴더 포함", isOn: $recursive)
            Divider()
            Button("드롭 영역 숨기기") { model.showsDropZone = false }
            Button("종료") { NSApp.terminate(nil) }
        }
        .animation(.easeInOut(duration: 0.15), value: isTargeted)
        .animation(.easeInOut(duration: 0.15), value: isHovering)
        .animation(.easeInOut(duration: 0.25), value: model.status)
    }

    // MARK: - Controls

    private var controls: some View {
        VStack {
            HStack {
                Spacer()
                controlButton("xmark", help: "드롭 영역 숨기기 — 메뉴 막대에서 다시 열 수 있음") {
                    model.showsDropZone = false
                }
            }

            Spacer()

            HStack(spacing: 6) {
                controlButton(
                    recursive ? "folder.fill" : "folder",
                    label: "하위 폴더",
                    isOn: recursive,
                    help: recursive ? "폴더 안의 모든 항목까지 변환" : "놓은 항목의 이름만 변환"
                ) {
                    recursive.toggle()
                }

                if hasCheckedNFD {
                    controlButton("arrow.triangle.2.circlepath", label: "변환", isOn: true, help: "확인한 항목을 NFC로 변환") {
                        model.convertChecked()
                    }
                } else {
                    controlButton("plus", label: "선택", help: "파일 선택… (⌘O)") {
                        model.chooseFiles()
                    }
                }
            }
        }
        .padding(8)
    }

    private func controlButton(
        _ systemImage: String,
        label: String? = nil,
        isOn: Bool = false,
        help: String,
        action: @escaping () -> Void
    ) -> some View {
        Button(action: action) {
            HStack(spacing: 3) {
                Image(systemName: systemImage)
                if let label {
                    Text(label)
                }
            }
            .font(.system(size: 10, weight: .semibold))
            .foregroundStyle(isOn ? Color.white : Color.secondary)
            .padding(.horizontal, label == nil ? 5 : 7)
            .padding(.vertical, 4)
            .background(
                Capsule().fill(isOn ? Color.accentColor : Color.secondary.opacity(0.15))
            )
        }
        .buttonStyle(.plain)
        .help(help)
    }

    // MARK: - Status

    @ViewBuilder
    private var statusIcon: some View {
        switch model.status {
        case .working:
            ProgressView()
                .controlSize(.regular)
        case .done(let outcome) where outcome.failed > 0:
            Image(systemName: "exclamationmark.triangle.fill")
                .foregroundStyle(.orange)
        case .done(let outcome) where outcome.renamed > 0:
            Image(systemName: "checkmark.circle.fill")
                .foregroundStyle(.green)
        case .done:
            Image(systemName: "checkmark.circle")
                .foregroundStyle(.secondary)
        case .checked(let result) where result.nfdNames.isEmpty:
            Image(systemName: "checkmark.seal.fill")
                .foregroundStyle(.green)
        case .checked:
            Image(systemName: "exclamationmark.circle.fill")
                .foregroundStyle(.orange)
        case .idle:
            Image(systemName: isTargeted ? "arrow.down.circle.fill" : "arrow.triangle.2.circlepath")
                .foregroundStyle(isTargeted ? Color.accentColor : .secondary)
        }
    }

    private var title: String {
        switch model.status {
        case .working: return "변환 중…"
        case .done(let outcome): return outcome.message
        case .checked(let result): return result.message
        case .idle: return isTargeted ? "놓아서 변환" : "NFD → NFC"
        }
    }

    private var subtitle: String {
        switch model.status {
        case .working:
            return " "
        case .done(let outcome) where outcome.failed > 0:
            return "마우스를 올려 자세히 보기"
        case .done(let outcome):
            return outcome.skipped > 0 && outcome.renamed > 0 ? "\(outcome.skipped)개는 이미 NFC" : " "
        case .checked(let result) where result.nfdNames.isEmpty:
            return "\(result.total)개 확인"
        case .checked(let result):
            return isHovering ? " " : "\(result.total)개 중 · 올려서 변환"
        case .idle:
            return isHovering ? " " : "놓으면 변환\n⌥ 누르고 놓으면 확인만"
        }
    }

    private var details: String? {
        switch model.status {
        case .done(let outcome): return outcome.failureDetails
        case .checked(let result): return result.details
        default: return nil
        }
    }

    private var hasCheckedNFD: Bool {
        if case .checked(let result) = model.status { return !result.nfdNames.isEmpty }
        return false
    }
}
