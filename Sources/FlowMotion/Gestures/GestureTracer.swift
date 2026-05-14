import SwiftUI
import os
import Observation

// MARK: - GestureTracer

/// Diagnostics layer for `GestureCoordinator`.
///
/// Records gesture lifecycle events, timing, and arbitration decisions.
/// In debug builds these are surfaced via `os_log` and an optional
/// overlay. In release builds all paths are no-ops.
@MainActor
@Observable
public final class GestureTracer {

    // MARK: Shared

    public static let shared = GestureTracer()

    // MARK: State

    private(set) var eventLog: [GestureEvent] = []
    private(set) var arbitrationLog: [ArbitrationDecision] = []

    private let logger = Logger(subsystem: "com.flowmotion", category: "GestureTracer")
    private let maxLogLength = 50

    private init() {}

    // MARK: - Recording

    func recordGestureChanged(id: String, displacement: CGFloat, velocity: CGFloat) {
        #if DEBUG
        let event = GestureEvent(
            id: id, phase: .changed,
            displacement: displacement, velocity: velocity, time: Date()
        )
        append(event: event)
        #endif
    }

    func recordGestureEnded(id: String, velocity: CGFloat, committed: Bool) {
        #if DEBUG
        let event = GestureEvent(
            id: id, phase: committed ? .committed : .cancelled,
            displacement: 0, velocity: velocity, time: Date()
        )
        append(event: event)
        logger.debug("Gesture \(id) \(committed ? "COMMITTED" : "CANCELLED") velocity=\(Int(velocity))")
        #endif
    }

    func recordArbitration(winner: String?, loser: String, reason: String) {
        #if DEBUG
        let decision = ArbitrationDecision(winner: winner, loser: loser, reason: reason, time: Date())
        if arbitrationLog.count >= maxLogLength { arbitrationLog.removeFirst() }
        arbitrationLog.append(decision)
        logger.debug("Arbitration: \(winner ?? "none") beats \(loser) [\(reason)]")
        #endif
    }

    private func append(event: GestureEvent) {
        if eventLog.count >= maxLogLength { eventLog.removeFirst() }
        eventLog.append(event)
    }

    // MARK: - Reset

    public func clear() {
        eventLog.removeAll()
        arbitrationLog.removeAll()
    }
}

// MARK: - Supporting types

public struct GestureEvent: Sendable {
    public enum Phase: Sendable { case changed, committed, cancelled }
    public let id: String
    public let phase: Phase
    public let displacement: CGFloat
    public let velocity: CGFloat
    public let time: Date
}

public struct ArbitrationDecision: Sendable {
    public let winner: String?
    public let loser: String
    public let reason: String
    public let time: Date
}

// MARK: - GestureCoordinator + tracing

public extension GestureCoordinator {
    /// Calls `shouldActivate` and records the arbitration decision.
    @MainActor
    func shouldActivateTraced<ID: Hashable>(
        _ id: ID,
        displacement: CGFloat
    ) -> Bool {
        let result = shouldActivate(id, displacement: displacement)
        if !result {
            GestureTracer.shared.recordArbitration(
                winner: activeGestureID.map { "\($0)" },
                loser: "\(id)",
                reason: "blocked"
            )
        }
        return result
    }
}

// MARK: - View modifier

public extension View {
    /// Shows a real-time gesture trace overlay. Debug builds only.
    func flowGestureTrace(enabled: Bool = true) -> some View {
        modifier(GestureTraceOverlayModifier(enabled: enabled))
    }
}

private struct GestureTraceOverlayModifier: ViewModifier {
    let enabled: Bool
    private let tracer = GestureTracer.shared

    func body(content: Content) -> some View {
        content.overlay(alignment: .topLeading) {
            #if DEBUG
            if enabled && !tracer.eventLog.isEmpty {
                GestureTracePanel(tracer: tracer)
                    .padding()
            }
            #endif
        }
    }
}

#if DEBUG
@MainActor
private struct GestureTracePanel: View {
    let tracer: GestureTracer

    var body: some View {
        VStack(alignment: .leading, spacing: 2) {
            Text("Gestures")
                .font(.system(size: 9, weight: .bold, design: .monospaced))
                .foregroundStyle(.cyan)

            ForEach(tracer.eventLog.suffix(6), id: \.time) { event in
                Text("\(event.id) \(phaseLabel(event.phase)) Δ\(Int(event.displacement)) v\(Int(event.velocity))")
                    .font(.system(size: 8, design: .monospaced))
                    .foregroundStyle(phaseColor(event.phase))
            }
        }
        .padding(6)
        .background(.black.opacity(0.72))
        .clipShape(RoundedRectangle(cornerRadius: 6, style: .continuous))
        .allowsHitTesting(false)
    }

    private func phaseLabel(_ phase: GestureEvent.Phase) -> String {
        switch phase {
        case .changed:   return "~"
        case .committed: return "✓"
        case .cancelled: return "✗"
        }
    }

    private func phaseColor(_ phase: GestureEvent.Phase) -> Color {
        switch phase {
        case .changed:   return .white.opacity(0.6)
        case .committed: return .green
        case .cancelled: return .orange
        }
    }
}
#endif
