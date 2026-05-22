import Foundation

/// Identifies which feature a queue/capture/response belongs to.
///
/// Used in three places:
/// - `LLMService.solve(...)` selects the prompt to send based on the kind.
/// - `AppDelegate` keeps one queue per kind and dispatches the "active" one.
/// - `OverlayContent.solution` carries the kind so the overlay can label
///   which feature responded (relevant when the user runs parallel flows).
enum HelperKind: Sendable, Equatable {
    case algorithmHelper
    case androidHelper

    /// Title shown at the top of the response in the overlay.
    var displayName: String {
        switch self {
        case .algorithmHelper: return "Algorithm Helper"
        case .androidHelper:   return "Android Helper"
        }
    }
}
