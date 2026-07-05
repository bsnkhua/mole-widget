import Foundation
import Observation

/// Owns the 24 h usage-history buffer. Samples the shared `MetricsStore` on its
/// own timer (independent of the widget refresh rate), persists each sample as
/// JSON Lines, prunes to the retention window, and compacts the file hourly.
@MainActor
@Observable
public final class UsageHistoryStore {
    /// Pruned, oldest-first. Drives the history window UI.
    public private(set) var samples: [UsageSample]

    @ObservationIgnored private let persistence: UsageHistoryPersistence
    @ObservationIgnored private let retention: TimeInterval
    @ObservationIgnored private let sampleInterval: TimeInterval
    @ObservationIgnored private weak var metrics: MetricsStore?
    @ObservationIgnored private var timer: Timer?
    @ObservationIgnored private var lastCompactedAt: Date?

    /// - Parameters:
    ///   - persistence: storage backend (inject a temp dir in tests).
    ///   - retention: how long to keep samples (default 12 h — covers an
    ///     overnight run; the chart's range selector narrows the view to 1/4/12 h
    ///     so peaks stay easy to scrub to).
    ///   - sampleInterval: minimum spacing between recorded samples (default 60 s).
    public init(
        persistence: UsageHistoryPersistence,
        retention: TimeInterval = 43_200,
        sampleInterval: TimeInterval = 60
    ) {
        self.persistence = persistence
        self.retention = retention
        self.sampleInterval = sampleInterval
        let loaded = UsageHistoryMath.pruned(persistence.loadAll(), now: Date(), retention: retention)
        self.samples = loaded
        // Compact once at startup so a pruned load doesn't leave stale lines on disk.
        persistence.rewrite(loaded)
        self.lastCompactedAt = Date()
    }

    /// Begins periodic sampling of `metrics`. Idempotent — a repeated call
    /// replaces the existing timer.
    public func start(reading metrics: MetricsStore) {
        self.metrics = metrics
        timer?.invalidate()
        // Check every 10 s; record() gates on sampleInterval so the effective
        // cadence is one sample per minute regardless of the tick rate.
        timer = Timer.scheduledTimer(withTimeInterval: 10, repeats: true) { [weak self] _ in
            Task { @MainActor in self?.tick() }
        }
    }

    public func stop() {
        timer?.invalidate()
        timer = nil
    }

    deinit {
        timer?.invalidate()
    }

    private func tick() {
        guard UsageHistoryMath.shouldRecord(lastAt: samples.last?.timestamp, now: Date(), interval: sampleInterval)
        else { return }
        record()
    }

    /// Snapshots the current metrics into a sample, appends it, prunes the
    /// in-memory buffer, and compacts the file at most once per hour.
    /// `internal` so tests can drive it deterministically.
    func record(now: Date = Date()) {
        guard let metrics, let cpu = metrics.cpu, let memory = metrics.memory else { return }

        let sample = UsageSample(
            timestamp: now,
            cpuFraction: cpu.totalUsage,
            memUsedBytes: memory.used,
            memTotalBytes: memory.total,
            topProcesses: metrics.topProcesses.map {
                UsageProcess(pid: $0.pid, name: $0.name, cpuFraction: $0.cpuFraction, memoryBytes: $0.memoryBytes)
            }
        )

        persistence.append(sample)
        samples.append(sample)
        samples = UsageHistoryMath.pruned(samples, now: now, retention: retention)

        if UsageHistoryMath.shouldRecord(lastAt: lastCompactedAt, now: now, interval: 3_600) {
            persistence.rewrite(samples)
            lastCompactedAt = now
        }
    }
}
