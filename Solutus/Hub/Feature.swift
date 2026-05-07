import Foundation

/// Model for a feature displayed in the hub.
///
/// Each feature carries its own `action`, injected by the caller (typically the
/// AppDelegate). The model knows nothing about UI or AppKit, which keeps it
/// trivially testable and the registry decoupled from side effects.
struct Feature: Identifiable {
    let id: String
    let title: String
    let subtitle: String
    let category: FeatureCategory
    let action: () -> Void
}

/// Visual category of a feature. Drives the badge rendered on the card.
///
/// Renaming a `rawValue` breaks any grep-by-category — keep them stable.
enum FeatureCategory: String {
    case swiftNative
    case pythonScript
    case shellCommand

    /// Short abbreviation used inside the card icon. Kept at 2 chars for
    /// consistent layout across categories.
    var iconLabel: String {
        switch self {
        case .swiftNative:   return "Sw"
        case .pythonScript:  return "Py"
        case .shellCommand:  return "Sh"
        }
    }

    /// Human-readable name shown next to the icon.
    var displayName: String {
        switch self {
        case .swiftNative:   return "Nativo"
        case .pythonScript:  return "Python"
        case .shellCommand:  return "Shell"
        }
    }
}
