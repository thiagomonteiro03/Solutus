import SwiftUI

// MARK: - Content Model

enum OverlayContent {
    case loading
    case solution(String)
    case error(String)
}

// MARK: - View

struct OverlayView: View {

    let content: OverlayContent
    let onDismiss: () -> Void

    var body: some View {
        ZStack {
            // Fundo vidro fosco
            RoundedRectangle(cornerRadius: 16)
                .fill(.ultraThinMaterial)
            RoundedRectangle(cornerRadius: 16)
                .strokeBorder(Color.white.opacity(0.12), lineWidth: 1)

            VStack(alignment: .leading, spacing: 0) {
                // Header
                HStack {
                    Circle()
                        .fill(Color.accentColor)
                        .frame(width: 8, height: 8)
                    Text("Solutus")
                        .font(.system(size: 12, weight: .semibold))
                        .foregroundStyle(.secondary)
                    Spacer()
                    Button(action: onDismiss) {
                        Image(systemName: "xmark.circle.fill")
                            .symbolRenderingMode(.hierarchical)
                            .foregroundStyle(.secondary)
                            .font(.system(size: 15))
                    }
                    .buttonStyle(.plain)
                    .keyboardShortcut(.escape, modifiers: [])
                }
                .padding(.horizontal, 16)
                .padding(.vertical, 12)

                Divider()
                    .opacity(0.4)

                // Body
                ScrollView {
                    bodyContent
                        .frame(maxWidth: .infinity, alignment: .leading)
                        .padding(16)
                }
            }
        }
        .frame(width: 420, height: 520)
        .shadow(color: .black.opacity(0.35), radius: 24, y: 8)
    }

    @ViewBuilder
    private var bodyContent: some View {
        switch content {
        case .loading:
            HStack(spacing: 10) {
                ProgressView()
                    .controlSize(.small)
                Text("Analisando a tela...")
                    .foregroundStyle(.secondary)
                    .font(.system(size: 13))
            }

        case .solution(let text):
            Text(text)
                .font(.system(size: 13))
                .lineSpacing(4)
                .textSelection(.enabled)

        case .error(let message):
            Label {
                Text(message)
                    .font(.system(size: 13))
                    .foregroundStyle(.red)
            } icon: {
                Image(systemName: "exclamationmark.triangle.fill")
                    .foregroundStyle(.red)
            }
        }
    }
}

#Preview {
    OverlayView(content: .solution("```swift\nfunc twoSum(_ nums: [Int], _ target: Int) -> [Int] {\n    var map = [Int: Int]()\n    for (i, n) in nums.enumerated() {\n        if let j = map[target - n] { return [j, i] }\n        map[n] = i\n    }\n    return []\n}\n```\nComplexidade O(n) usando hash map."), onDismiss: {})
        .preferredColorScheme(.dark)
}
