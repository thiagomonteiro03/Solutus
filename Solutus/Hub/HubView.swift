import SwiftUI

/// Root view of the hub: header + adaptive grid of feature cards.
///
/// Receives `features` by parameter (DI) — does not consult the registry
/// directly. Kept small and stateless: it just composes the private subviews
/// declared below.
struct HubView: View {

    let features: [Feature]

    var body: some View {
        VStack(alignment: .leading, spacing: 18) {
            HubHeader()
            FeaturesGrid(features: features)
            Spacer(minLength: 0)
        }
        .padding(20)
        .frame(minWidth: 520, minHeight: 360)
    }
}

private struct HubHeader: View {
    var body: some View {
        VStack(alignment: .leading, spacing: 4) {
            Text("Solutus Hub")
                .font(.title2.weight(.semibold))
            Text("Selecione uma feature pra executar")
                .font(.caption)
                .foregroundStyle(.secondary)
        }
    }
}

private struct FeaturesGrid: View {

    let features: [Feature]

    private let columns = [GridItem(.adaptive(minimum: 160), spacing: 12)]

    var body: some View {
        LazyVGrid(columns: columns, spacing: 12) {
            ForEach(features) { feature in
                FeatureCard(feature: feature)
            }
        }
    }
}

private struct FeatureCard: View {

    let feature: Feature

    @State private var isHovering = false

    var body: some View {
        Button(action: feature.action) {
            content
        }
        .buttonStyle(.plain)
        .onHover { isHovering = $0 }
    }

    private var content: some View {
        VStack(alignment: .leading, spacing: 10) {
            CategoryBadge(category: feature.category)
            Text(feature.title)
                .font(.body.weight(.medium))
                .foregroundStyle(.primary)
            Text(feature.subtitle)
                .font(.caption)
                .foregroundStyle(.secondary)
                .lineLimit(2)
                .fixedSize(horizontal: false, vertical: true)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(12)
        .background(background)
        .overlay(border)
        .contentShape(Rectangle())
    }

    private var background: some View {
        RoundedRectangle(cornerRadius: 8)
            .fill(isHovering ? Color.gray.opacity(0.12) : Color.clear)
    }

    private var border: some View {
        RoundedRectangle(cornerRadius: 8)
            .stroke(Color.gray.opacity(0.25), lineWidth: 0.5)
    }
}

private struct CategoryBadge: View {

    let category: FeatureCategory

    var body: some View {
        HStack(spacing: 6) {
            Text(category.iconLabel)
                .font(.caption.weight(.semibold))
                .padding(.horizontal, 6)
                .padding(.vertical, 2)
                .background(Color.accentColor.opacity(0.18))
                .clipShape(RoundedRectangle(cornerRadius: 4))
                .foregroundStyle(Color.accentColor)
            Text(category.displayName)
                .font(.caption2)
                .foregroundStyle(.secondary)
        }
    }
}

#Preview {
    HubView(features: [
        Feature(
            id: "algorithm-helper",
            title: "Algorithm Helper",
            subtitle: "Captura tela e resolve via IA",
            category: .swiftNative,
            action: {}
        )
    ])
}
