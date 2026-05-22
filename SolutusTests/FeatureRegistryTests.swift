import Testing
@testable import Solutus

/// Verifies the contents returned by `defaultFeatures(...)` and — critical —
/// that the injected closures only run when `feature.action` is actually
/// invoked. If the registry triggered side effects at construction time, the
/// app would pop alerts at startup.
@Suite("FeatureRegistry")
@MainActor
struct FeatureRegistryTests {

    // MARK: - Algorithm Helper

    @Test("defaultFeatures includes Algorithm Helper")
    func defaultFeaturesIncludesAlgorithmHelper() {
        let features = makeFeatures()
        #expect(features.contains { $0.id == "algorithm-helper" })
    }

    @Test("Algorithm Helper is in the swiftNative category")
    func algorithmHelperIsSwiftNative() {
        let features = makeFeatures()
        let helper = features.first { $0.id == "algorithm-helper" }
        #expect(helper?.category == .swiftNative)
    }

    @Test("Algorithm Helper has populated title and subtitle")
    func algorithmHelperHasContent() {
        let features = makeFeatures()
        let helper = features.first { $0.id == "algorithm-helper" }
        #expect(helper?.title.isEmpty == false)
        #expect(helper?.subtitle.isEmpty == false)
    }

    // MARK: - Android Helper

    @Test("defaultFeatures includes Android Helper")
    func defaultFeaturesIncludesAndroidHelper() {
        let features = makeFeatures()
        #expect(features.contains { $0.id == "android-helper" })
    }

    @Test("Android Helper is in the swiftNative category")
    func androidHelperIsSwiftNative() {
        let features = makeFeatures()
        let helper = features.first { $0.id == "android-helper" }
        #expect(helper?.category == .swiftNative)
    }

    @Test("Android Helper has populated title and subtitle")
    func androidHelperHasContent() {
        let features = makeFeatures()
        let helper = features.first { $0.id == "android-helper" }
        #expect(helper?.title.isEmpty == false)
        #expect(helper?.subtitle.isEmpty == false)
    }

    // MARK: - Registry invariants

    @Test("feature ids are unique (stable key for ForEach in HubView)")
    func featureIdsAreUnique() {
        let features = makeFeatures()
        let ids = features.map(\.id)
        #expect(Set(ids).count == ids.count)
    }

    @Test("registry exposes both helpers (Algorithm + Android)")
    func registryExposesBothHelpers() {
        let features = makeFeatures()
        // Ensures adding the Android feature did not remove or alter the
        // Algorithm one — the Hub expects both.
        #expect(features.count == 2)
    }

    // MARK: - Lazy closures

    @Test("Algorithm Helper closure is lazy — only fires when action is invoked")
    func algorithmClosureIsLazy() {
        let spy = HintInvocationSpy()

        let features = FeatureRegistry.defaultFeatures(
            showAlgorithmHelperHint: { spy.record() },
            showAndroidHelperHint: {}
        )

        #expect(spy.callCount == 0)

        features.first { $0.id == "algorithm-helper" }?.action()
        #expect(spy.callCount == 1)
    }

    @Test("Android Helper closure is lazy — only fires when action is invoked")
    func androidClosureIsLazy() {
        let spy = HintInvocationSpy()

        let features = FeatureRegistry.defaultFeatures(
            showAlgorithmHelperHint: {},
            showAndroidHelperHint: { spy.record() }
        )

        // Building the registry MUST NOT fire the closure — otherwise the
        // alert would appear at app launch.
        #expect(spy.callCount == 0)

        features.first { $0.id == "android-helper" }?.action()
        #expect(spy.callCount == 1)
    }

    // MARK: - Helpers

    /// Builds the registry with empty closures — used by tests that only
    /// inspect metadata (id, category, title, subtitle).
    private func makeFeatures() -> [Feature] {
        FeatureRegistry.defaultFeatures(
            showAlgorithmHelperHint: {},
            showAndroidHelperHint: {}
        )
    }
}

/// Local spy: counts how many times the hint closure was invoked.
/// Implemented as a class (rather than a closure capturing a `var`) to avoid
/// Sendable warnings under strict concurrency.
@MainActor
private final class HintInvocationSpy {
    private(set) var callCount = 0
    func record() { callCount += 1 }
}
