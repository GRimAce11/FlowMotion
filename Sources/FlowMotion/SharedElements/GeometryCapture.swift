import SwiftUI

// MARK: - GeometryCapture

/// `PreferenceKey` that collects shared-element frames from the view hierarchy.
///
/// Each tagged view pushes its global frame up the tree. A parent overlay reads
/// the accumulated frames and feeds them to ``SharedElementRegistry``.
struct SharedElementPreference: PreferenceKey {
    typealias Value = [SharedElementFrame]

    static let defaultValue: [SharedElementFrame] = []

    static func reduce(value: inout [SharedElementFrame], nextValue: () -> [SharedElementFrame]) {
        value.append(contentsOf: nextValue())
    }
}

/// A single shared-element frame captured in the preference system.
public struct SharedElementFrame: @unchecked Sendable, Equatable {
    public let id: AnyHashable
    public let frame: CGRect
    public let role: ElementRole

    public static func == (lhs: Self, rhs: Self) -> Bool {
        lhs.id == rhs.id && lhs.frame == rhs.frame
    }
}

// MARK: - GeometryCaptureModifier

/// Reads its own global frame via `GeometryReader` + `CoordinateSpace.global`
/// and publishes it through `SharedElementPreference`.
struct GeometryCaptureModifier: ViewModifier {
    let id: AnyHashable
    let role: ElementRole

    func body(content: Content) -> some View {
        content
            .background(
                GeometryReader { proxy in
                    Color.clear.preference(
                        key: SharedElementPreference.self,
                        value: [
                            SharedElementFrame(
                                id: id,
                                frame: proxy.frame(in: .global),
                                role: role
                            )
                        ]
                    )
                }
            )
    }
}

// MARK: - Registry sink

/// Reads `SharedElementPreference` values and writes them to the registry.
struct SharedElementRegistrySink: ViewModifier {
    func body(content: Content) -> some View {
        content
            .onPreferenceChange(SharedElementPreference.self) { frames in
                Task { @MainActor in
                    for frame in frames {
                        SharedElementRegistry.shared.register(
                            id: frame.id,
                            frame: frame.frame,
                            role: frame.role
                        )
                    }
                }
            }
    }
}

// MARK: - View helpers

extension View {
    /// Captures global geometry for a shared element and registers it.
    func captureGeometry(id: AnyHashable, role: ElementRole = .neutral) -> some View {
        modifier(GeometryCaptureModifier(id: id, role: role))
    }

    /// Installs the registry sink at a container level (call once near root).
    func installGeometrySink() -> some View {
        modifier(SharedElementRegistrySink())
    }
}
