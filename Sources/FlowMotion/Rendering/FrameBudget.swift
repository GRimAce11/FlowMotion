import SwiftUI
import QuartzCore
import Observation

// MARK: - FrameBudgetMonitor

/// Monitors display frame pacing and exposes adaptive quality signals
/// to the rendering pipeline.
///
/// The monitor uses a `CADisplayLink` (iOS/macOS) to record actual frame
/// timestamps at display frequency. It computes a rolling 30-frame average
/// and emits quality-tier changes when the average deviates from the target.
///
/// ## Usage
/// ```swift
/// // Install at app root
/// MyView().flowFrameBudget()
///
/// // Read quality in any child view
/// @Environment(\.frameBudgetQuality) var quality
/// Canvas { ... }
///     .blur(radius: quality.blurRadius)
/// ```
@MainActor
@Observable
public final class FrameBudgetMonitor {

    // MARK: Shared

    public static let shared = FrameBudgetMonitor()

    // MARK: Configuration

    public var targetFPS: Double = 60

    // MARK: Observable state

    private(set) public var currentTier: QualityTier = .high
    private(set) public var measuredFPS: Double = 60
    private(set) public var droppedFrameCount: Int = 0

    // MARK: Private

    private var displayLink: CADisplayLink?
    private var frameTimes: [CFAbsoluteTime] = []
    private let historyLength = 30
    private var isRunning = false

    private init() {}

    // MARK: - Control

    /// Starts frame-rate monitoring.
    public func start() {
        guard !isRunning else { return }
        isRunning = true
        frameTimes.removeAll()

        #if canImport(UIKit)
        let link = CADisplayLink(target: DisplayLinkProxy(monitor: self), selector: #selector(DisplayLinkProxy.tick(_:)))
        link.add(to: .main, forMode: .common)
        displayLink = link
        #endif
    }

    /// Stops frame-rate monitoring and resets state.
    public func stop() {
        displayLink?.invalidate()
        displayLink = nil
        isRunning = false
    }

    // MARK: - Internal frame recording

    func recordFrame(timestamp: CFAbsoluteTime) {
        frameTimes.append(timestamp)
        if frameTimes.count > historyLength {
            frameTimes.removeFirst()
        }
        updateMetrics()
    }

    private func updateMetrics() {
        guard frameTimes.count >= 5 else { return }

        let intervals = zip(frameTimes, frameTimes.dropFirst()).map { $1 - $0 }
        let avgInterval = intervals.reduce(0, +) / Double(intervals.count)
        guard avgInterval > 0 else { return }

        measuredFPS = 1.0 / avgInterval

        let droppedInWindow = intervals.filter { $0 > (1.0 / targetFPS) * 1.5 }.count
        droppedFrameCount = droppedInWindow

        let newTier = QualityTier(fps: measuredFPS, target: targetFPS)
        if newTier != currentTier {
            currentTier = newTier
        }
    }
}

// MARK: - QualityTier

/// The adaptive rendering quality tier selected by `FrameBudgetMonitor`.
public enum QualityTier: Int, Sendable, Comparable, CustomStringConvertible {
    case ultra  = 3
    case high   = 2
    case medium = 1
    case low    = 0

    public static func < (lhs: Self, rhs: Self) -> Bool {
        lhs.rawValue < rhs.rawValue
    }

    /// Initialises from a measured FPS and target.
    init(fps: Double, target: Double) {
        switch fps / target {
        case 0.98...: self = .ultra
        case 0.85...: self = .high
        case 0.65...: self = .medium
        default:      self = .low
        }
    }

    /// Gaussian blur radius appropriate for this tier.
    public var blurRadius: CGFloat {
        switch self {
        case .ultra:  return 18
        case .high:   return 12
        case .medium: return 6
        case .low:    return 2
        }
    }

    /// Canvas detail level (point count for curve sampling).
    public var morphSampleCount: Int {
        switch self {
        case .ultra:  return 256
        case .high:   return 128
        case .medium: return 64
        case .low:    return 32
        }
    }

    /// Liquid wave step count (fewer = faster but less smooth).
    public var waveStepCount: Int {
        switch self {
        case .ultra:  return 80
        case .high:   return 60
        case .medium: return 40
        case .low:    return 20
        }
    }

    public var description: String {
        switch self {
        case .ultra:  return "Ultra"
        case .high:   return "High"
        case .medium: return "Medium"
        case .low:    return "Low"
        }
    }
}

// MARK: - CADisplayLink proxy

/// Bridges the CADisplayLink Obj-C callback to the Swift actor.
#if canImport(UIKit)
private final class DisplayLinkProxy: NSObject, @unchecked Sendable {
    weak var monitor: FrameBudgetMonitor?

    init(monitor: FrameBudgetMonitor) {
        self.monitor = monitor
    }

    @objc func tick(_ link: CADisplayLink) {
        let ts = link.timestamp
        Task { @MainActor [weak self] in
            self?.monitor?.recordFrame(timestamp: ts)
        }
    }
}
#endif

// MARK: - EnvironmentKey

private struct FrameBudgetKey: EnvironmentKey {
    static let defaultValue: QualityTier = .high
}

public extension EnvironmentValues {
    /// The current adaptive quality tier — updated by `FrameBudgetMonitor`.
    var frameBudgetQuality: QualityTier {
        get { self[FrameBudgetKey.self] }
        set { self[FrameBudgetKey.self] = newValue }
    }
}

// MARK: - View modifier

public extension View {
    /// Installs the frame budget monitor and injects quality signals into
    /// the view hierarchy. Call once at the root.
    func flowFrameBudget() -> some View {
        modifier(FrameBudgetModifier())
    }
}

private struct FrameBudgetModifier: ViewModifier {
    private let monitor = FrameBudgetMonitor.shared

    func body(content: Content) -> some View {
        content
            .environment(\.frameBudgetQuality, monitor.currentTier)
            .onAppear  { monitor.start() }
            .onDisappear { monitor.stop() }
    }
}

// MARK: - Debug overlay

public extension View {
    /// Shows a small FPS/quality indicator in the corner. Debug only.
    func flowFPSOverlay(enabled: Bool = true) -> some View {
        modifier(FPSOverlayModifier(enabled: enabled))
    }
}

private struct FPSOverlayModifier: ViewModifier {
    let enabled: Bool
    private let monitor = FrameBudgetMonitor.shared

    func body(content: Content) -> some View {
        content.overlay(alignment: .topTrailing) {
            #if DEBUG
            if enabled {
                FPSLabel(monitor: monitor)
                    .padding(8)
            }
            #endif
        }
    }
}

#if DEBUG
@MainActor
private struct FPSLabel: View {
    let monitor: FrameBudgetMonitor

    private var color: Color {
        switch monitor.currentTier {
        case .ultra, .high: return .green
        case .medium:       return .yellow
        case .low:          return .red
        }
    }

    var body: some View {
        Text("\(Int(monitor.measuredFPS)) fps · \(monitor.currentTier.description)")
            .font(.system(size: 9, weight: .medium, design: .monospaced))
            .foregroundStyle(color)
            .padding(.horizontal, 6)
            .padding(.vertical, 3)
            .background(.black.opacity(0.6))
            .clipShape(Capsule())
            .allowsHitTesting(false)
    }
}
#endif
