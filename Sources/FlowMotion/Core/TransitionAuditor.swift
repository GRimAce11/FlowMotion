import SwiftUI
import Observation
import os

// MARK: - TransitionAuditor

/// Runtime auditor for transition lifecycle events.
///
/// `TransitionAuditor` tracks every in-flight transition, detects stuck states,
/// and provides structured logging. In debug builds it can surface a diagnostic
/// overlay via `.flowDebugOverlay()`.
///
/// It is designed to be zero-overhead in release builds — all expensive
/// paths are guarded by `#if DEBUG`.
@MainActor
@Observable
public final class TransitionAuditor {

    // MARK: Shared

    public static let shared = TransitionAuditor()

    // MARK: Configuration

    /// Duration (seconds) after which an un-completed transition is considered "stuck".
    public var stuckTransitionThreshold: TimeInterval = 2.0

    /// Whether to emit `os_log` trace events for each lifecycle step.
    public var loggingEnabled: Bool = {
        #if DEBUG
        return true
        #else
        return false
        #endif
    }()

    // MARK: State

    private(set) var records: [TransitionID: TransitionRecord] = [:]
    private(set) var stuckTransitions: [TransitionID] = []
    private(set) var totalCompleted: Int = 0
    private(set) var totalCancelled: Int = 0

    private var stuckCheckTask: Task<Void, Never>?
    private let logger = Logger(subsystem: "com.flowmotion", category: "TransitionAuditor")

    private init() {
        startStuckDetection()
    }

    // MARK: - Lifecycle

    /// Records the start of a transition.
    @discardableResult
    public func began(
        id: TransitionID,
        kind: TransitionKind,
        elementID: AnyHashable? = nil
    ) -> TransitionRecord {
        let record = TransitionRecord(
            id: id,
            kind: kind,
            elementID: elementID,
            startTime: Date()
        )
        records[id] = record
        log("began \(kind) transition \(id.rawValue)")
        return record
    }

    /// Marks a transition as completed.
    public func completed(id: TransitionID) {
        guard records[id] != nil else { return }
        records.removeValue(forKey: id)
        totalCompleted += 1
        stuckTransitions.removeAll { $0 == id }
        log("completed transition \(id.rawValue)")
    }

    /// Marks a transition as cancelled (e.g., interrupted by gesture).
    public func cancelled(id: TransitionID) {
        guard records[id] != nil else { return }
        records.removeValue(forKey: id)
        totalCancelled += 1
        stuckTransitions.removeAll { $0 == id }
        log("cancelled transition \(id.rawValue)")
    }

    /// Force-cleans all active transitions. Call on scene reset or navigation root replacement.
    public func forceCleanAll() {
        let count = records.count
        records.removeAll()
        stuckTransitions.removeAll()
        log("force-cleaned \(count) active transitions")
        // Also clean the hero overlay
        SharedElementRegistry.shared.cancelHero()
    }

    // MARK: - Stuck detection

    private func startStuckDetection() {
        stuckCheckTask = Task { [weak self] in
            while !Task.isCancelled {
                try? await Task.sleep(nanoseconds: 500_000_000)  // 0.5s
                await MainActor.run { self?.checkForStuckTransitions() }
            }
        }
    }

    private func checkForStuckTransitions() {
        let now = Date()
        let newlyStuck = records.values.filter { record in
            now.timeIntervalSince(record.startTime) > stuckTransitionThreshold
            && !stuckTransitions.contains(record.id)
        }
        for record in newlyStuck {
            stuckTransitions.append(record.id)
            log("⚠️ STUCK transition \(record.id.rawValue) [\(record.kind)] — exceeded \(stuckTransitionThreshold)s")
        }
    }

    // MARK: - Diagnostics

    /// A human-readable summary of current transition state.
    public var diagnosticSummary: String {
        """
        FlowMotion Transitions
        ─────────────────────
        Active:    \(records.count)
        Stuck:     \(stuckTransitions.count)
        Completed: \(totalCompleted)
        Cancelled: \(totalCancelled)
        Active IDs: \(records.keys.map(\.rawValue).sorted().joined(separator: ", "))
        """
    }

    // MARK: - Private helpers

    private func log(_ message: String) {
        guard loggingEnabled else { return }
        #if DEBUG
        logger.debug("[\(message)]")
        #endif
    }
}

// MARK: - Supporting types

public struct TransitionID: Hashable, Sendable {
    public let rawValue: String

    public init(_ value: String) {
        self.rawValue = value
    }

    public static func hero(_ elementID: some Hashable) -> TransitionID {
        TransitionID("hero:\(elementID)")
    }

    public static func navigation(_ id: String = UUID().uuidString) -> TransitionID {
        TransitionID("nav:\(id)")
    }

    public static func modal(_ id: String = UUID().uuidString) -> TransitionID {
        TransitionID("modal:\(id)")
    }
}

public enum TransitionKind: String, Sendable {
    case hero       = "hero"
    case navigation = "navigation"
    case modal      = "modal"
    case dismiss    = "dismiss"
    case interactive = "interactive"
}

public struct TransitionRecord: @unchecked Sendable {
    public let id: TransitionID
    public let kind: TransitionKind
    public let elementID: AnyHashable?
    public let startTime: Date

    var age: TimeInterval { Date().timeIntervalSince(startTime) }
}

// MARK: - Debug overlay

public extension View {
    /// Attaches a diagnostic overlay showing active transition state.
    /// No-ops in release builds.
    func flowDebugOverlay(enabled: Bool = true) -> some View {
        modifier(FlowDebugOverlayModifier(enabled: enabled))
    }
}

private struct FlowDebugOverlayModifier: ViewModifier {
    let enabled: Bool
    private let auditor = TransitionAuditor.shared

    func body(content: Content) -> some View {
        content.overlay(alignment: .bottomLeading) {
            #if DEBUG
            if enabled {
                DebugPanel(auditor: auditor)
            }
            #endif
        }
    }
}

#if DEBUG
@MainActor
private struct DebugPanel: View {
    let auditor: TransitionAuditor

    var body: some View {
        VStack(alignment: .leading, spacing: 4) {
            Text("FlowMotion Debug")
                .font(.system(size: 10, weight: .bold, design: .monospaced))
                .foregroundStyle(.yellow)

            Text("Active: \(auditor.records.count)")
                .font(.system(size: 9, design: .monospaced))
                .foregroundStyle(auditor.records.isEmpty ? .green : .orange)

            if !auditor.stuckTransitions.isEmpty {
                Text("STUCK: \(auditor.stuckTransitions.count)")
                    .font(.system(size: 9, weight: .bold, design: .monospaced))
                    .foregroundStyle(.red)
            }

            Text("Done: \(auditor.totalCompleted) | Cancel: \(auditor.totalCancelled)")
                .font(.system(size: 9, design: .monospaced))
                .foregroundStyle(.secondary)
        }
        .padding(8)
        .background(.black.opacity(0.75))
        .clipShape(RoundedRectangle(cornerRadius: 8, style: .continuous))
        .padding(12)
        .allowsHitTesting(false)
    }
}
#endif
