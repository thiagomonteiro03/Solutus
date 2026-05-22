import Foundation

/// Central registry of features available in the hub.
///
/// Actions are injected (DI) — the registry knows nothing about AppKit or the
/// overlay. This lets `defaultFeatures(...)` be called from tests with fake
/// closures, verifying that each Feature is registered with the right
/// category/title without firing real side effects.
///
/// To add a new feature: add a closure parameter here plus an entry in the array.
enum FeatureRegistry {

    static func defaultFeatures(
        showAlgorithmHelperHint: @escaping () -> Void,
        showAndroidHelperHint:   @escaping () -> Void
    ) -> [Feature] {
        [
            algorithmHelper(action: showAlgorithmHelperHint),
            androidHelper(action: showAndroidHelperHint)
        ]
    }

    private static func algorithmHelper(action: @escaping () -> Void) -> Feature {
        Feature(
            id: "algorithm-helper",
            title: "Algorithm Helper",
            subtitle: "Captura tela e resolve via IA",
            category: .swiftNative,
            action: action
        )
    }

    private static func androidHelper(action: @escaping () -> Void) -> Feature {
        Feature(
            id: "android-helper",
            title: "Android Helper",
            subtitle: "Captura enunciado de Android/Kotlin e responde via IA",
            category: .swiftNative,
            action: action
        )
    }
}
