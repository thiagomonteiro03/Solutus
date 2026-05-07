import Testing
@testable import Solutus

/// Ensures the `Feature` model preserves the values it receives and that its
/// `action` is purely passive — only fires when explicitly invoked.
@Suite("Feature")
struct FeatureTests {

    @Test("preserves all fields passed at initialization")
    func storesAllFields() {
        let feature = Feature(
            id: "test-id",
            title: "Test Title",
            subtitle: "Test Subtitle",
            category: .pythonScript,
            action: {}
        )

        #expect(feature.id == "test-id")
        #expect(feature.title == "Test Title")
        #expect(feature.subtitle == "Test Subtitle")
        #expect(feature.category == .pythonScript)
    }

    @Test("Identifiable uses the feature's own id")
    func isIdentifiable() {
        let feature = Feature(
            id: "stable-id",
            title: "x",
            subtitle: "x",
            category: .shellCommand,
            action: {}
        )

        // Guarantees that ForEach(features) inside HubView can identify
        // each card uniformly by its feature id.
        #expect(feature.id == "stable-id")
    }

    @Test("action is invoked exactly the number of times it is called")
    @MainActor
    func actionIsInvokedOncePerCall() {
        let spy = ActionSpy()
        let feature = Feature(
            id: "x",
            title: "x",
            subtitle: "x",
            category: .swiftNative,
            action: { spy.record() }
        )

        feature.action()
        feature.action()
        feature.action()
        #expect(spy.callCount == 3)
    }
}

/// Covers the category → display-text mapping and the stability of the raw
/// values (used as stable keys for grep and any future serialization).
@Suite("FeatureCategory")
struct FeatureCategoryTests {

    @Test("iconLabel returns a 2-char abbreviation per category")
    func iconLabelsAreTwoCharsPerCategory() {
        let mapping: [(FeatureCategory, String)] = [
            (.swiftNative,   "Sw"),
            (.pythonScript,  "Py"),
            (.shellCommand,  "Sh")
        ]

        for (category, expected) in mapping {
            #expect(category.iconLabel == expected)
            #expect(category.iconLabel.count == 2)
        }
    }

    @Test("displayName returns the human-readable name per category")
    func displayNamePerCategory() {
        #expect(FeatureCategory.swiftNative.displayName  == "Nativo")
        #expect(FeatureCategory.pythonScript.displayName == "Python")
        #expect(FeatureCategory.shellCommand.displayName == "Shell")
    }

    @Test("rawValues are stable (grep and future persistence depend on them)")
    func rawValuesAreStable() {
        // If anyone renames these raw values, code that filters by category or
        // persists user preferences would break silently.
        #expect(FeatureCategory.swiftNative.rawValue   == "swiftNative")
        #expect(FeatureCategory.pythonScript.rawValue  == "pythonScript")
        #expect(FeatureCategory.shellCommand.rawValue  == "shellCommand")
    }
}

/// Local spy that counts action invocations without capturing a `var` in a
/// closure (which triggers Sendable warnings under Swift 6 strict concurrency).
@MainActor
private final class ActionSpy {
    private(set) var callCount = 0
    func record() { callCount += 1 }
}
