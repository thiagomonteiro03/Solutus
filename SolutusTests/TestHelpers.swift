import AppKit
import Foundation
@testable import Solutus

/// Shared utilities used by the unit tests.
enum TestHelpers {

    /// Produces a valid solid NSImage to exercise conversions and flows that
    /// expect real screenshots (it has a usable `tiffRepresentation`).
    /// Requires MainActor because `lockFocus`/`unlockFocus` are thread-sensitive.
    @MainActor
    static func makeSolidImage(
        size: NSSize = NSSize(width: 32, height: 32),
        color: NSColor = .red
    ) -> NSImage {
        let image = NSImage(size: size)
        image.lockFocus()
        color.setFill()
        NSRect(origin: .zero, size: size).fill()
        image.unlockFocus()
        return image
    }

    /// A "broken" NSImage — with no bitmap representation — used to force
    /// conversion failures (covers the `.imageConversionFailed` path).
    static func makeEmptyImage() -> NSImage {
        NSImage(size: .zero)
    }

    /// Saves and restores environment variables during a test block.
    /// Some tests need to simulate OPENAI_API_KEY being present or absent.
    static func withEnvironment(
        key: String,
        value: String?,
        perform: () async throws -> Void
    ) async rethrows {
        let previous = ProcessInfo.processInfo.environment[key]
        if let value {
            setenv(key, value, 1)
        } else {
            unsetenv(key)
        }
        defer {
            if let previous {
                setenv(key, previous, 1)
            } else {
                unsetenv(key)
            }
        }
        try await perform()
    }
}
