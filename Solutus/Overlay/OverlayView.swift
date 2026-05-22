import SwiftUI

// MARK: - Content Model

enum OverlayContent {
    case captured(count: Int)
    case loading
    /// `source` identifies which feature responded — rendered as a header at
    /// the top of the response body so the user can disambiguate parallel
    /// flows (Algorithm Helper × Android Helper).
    case solution(text: String, source: HelperKind)
    case error(String)
}

// MARK: - View

struct OverlayView: View {

    let content: OverlayContent
    let onDismiss: () -> Void

    var body: some View {
        ZStack {
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

                Divider().opacity(0.4)

                // Body
                ScrollView {
                    bodyContent
                        .frame(maxWidth: .infinity, alignment: .leading)
                        .padding(16)
                }
            }
        }
        .frame(width: 420, height: frameHeight)
        .shadow(color: .black.opacity(0.35), radius: 24, y: 8)
        .animation(.easeInOut(duration: 0.2), value: frameHeight)
    }

    // Smaller height in capture/loading states, larger for solution/error.
    private var frameHeight: CGFloat {
        switch content {
        case .captured: return 110
        case .loading:  return 110
        default:        return 520
        }
    }

    @ViewBuilder
    private var bodyContent: some View {
        switch content {
        case .captured(let count):
            HStack(spacing: 10) {
                Image(systemName: "photo.stack.fill")
                    .foregroundStyle(.blue)
                VStack(alignment: .leading, spacing: 2) {
                    Text("\(count) tela\(count > 1 ? "s" : "") capturada\(count > 1 ? "s" : "")")
                        .font(.system(size: 13, weight: .medium))
                    Text("⌘+Shift+S para mais  ·  ⌘+Shift+↩ para enviar")
                        .font(.system(size: 11))
                        .foregroundStyle(.secondary)
                }
            }

        case .loading:
            HStack(spacing: 10) {
                ProgressView().controlSize(.small)
                Text("Analisando...")
                    .foregroundStyle(.secondary)
                    .font(.system(size: 13))
            }

        case .solution(let text, let source):
            VStack(alignment: .leading, spacing: 8) {
                Text(source.displayName)
                    .font(.system(size: 11, weight: .semibold))
                    .foregroundStyle(.secondary)
                    .textCase(.uppercase)
                Divider().opacity(0.4)
                Text(text)
                    .font(.system(size: 13))
                    .lineSpacing(4)
                    .textSelection(.enabled)
            }

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

#Preview("Captured") {
    OverlayView(content: .captured(count: 2), onDismiss: {})
        .preferredColorScheme(.dark)
}

#Preview("Solution (Algorithm)") {
    OverlayView(
        content: .solution(
            text: "Use a hash map to solve in O(n).\n\n```swift\nfunc twoSum(_ nums: [Int], _ target: Int) -> [Int] {\n    var map = [Int: Int]()\n    for (i, n) in nums.enumerated() {\n        if let j = map[target - n] { return [j, i] }\n        map[n] = i\n    }\n    return []\n}\n```",
            source: .algorithmHelper
        ),
        onDismiss: {}
    )
    .preferredColorScheme(.dark)
}

#Preview("Solution (Android)") {
    OverlayView(
        content: .solution(
            text: "// 1 - Collect the StateFlow inside the composable\n// 2 - Hoist the state up to the ViewModel\n// 3 - Render based on the resulting UiState\n\n```kotlin\n@Composable\nfun Greeting(viewModel: GreetingViewModel) {\n    val state by viewModel.state.collectAsState()\n    Text(state.message)\n}\n```",
            source: .androidHelper
        ),
        onDismiss: {}
    )
    .preferredColorScheme(.dark)
}
