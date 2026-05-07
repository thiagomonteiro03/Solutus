import Testing
@testable import Solutus

/// Verifies the contents returned by `defaultFeatures(...)` and — critical —
/// that the injected closures only run when `feature.action` is actually
/// invoked. If the registry triggered side effects at construction time, the
/// app would pop alerts at startup.
@Suite("FeatureRegistry")
@MainActor
struct FeatureRegistryTests {

    @Test("defaultFeatures includes Algorithm Helper")
    func defaultFeaturesIncludesAlgorithmHelper() {
        let features = FeatureRegistry.defaultFeatures(showAlgorithmHelperHint: {})

        #expect(features.contains { $0.id == "algorithm-helper" })
    }

    @Test("Algorithm Helper is in the swiftNative category")
    func algorithmHelperIsSwiftNative() {
        let features = FeatureRegistry.defaultFeatures(showAlgorithmHelperHint: {})
        let helper = features.first { $0.id == "algorithm-helper" }

        #expect(helper?.category == .swiftNative)
    }

    @Test("Algorithm Helper has populated title and subtitle")
    func algorithmHelperHasContent() {
        let features = FeatureRegistry.defaultFeatures(showAlgorithmHelperHint: {})
        let helper = features.first { $0.id == "algorithm-helper" }

        #expect(helper?.title.isEmpty == false)
        #expect(helper?.subtitle.isEmpty == false)
    }

    @Test("feature ids are unique (stable key for ForEach in HubView)")
    func featureIdsAreUnique() {
        let features = FeatureRegistry.defaultFeatures(showAlgorithmHelperHint: {})
        let ids = features.map(\.id)

        #expect(Set(ids).count == ids.count)
    }

    @Test("the injected closure is lazy — it only fires when feature.action is called")
    func injectedClosureIsLazy() {
        let spy = HintInvocationSpy()

        let features = FeatureRegistry.defaultFeatures(
            showAlgorithmHelperHint: { spy.record() }
        )

        // Constructing the registry MUST NOT invoke the closure. Otherwise side
        // effects (NSAlert, etc.) would fire as soon as the app launches.
        #expect(spy.callCount == 0)

        features.first { $0.id == "algorithm-helper" }?.action()
        #expect(spy.callCount == 1)
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
