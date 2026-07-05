import Foundation

/// Pure helpers for the usage-history buffer: retention pruning, sample-rate
/// gating, and nearest-point lookup for the scrubber.
public enum UsageHistoryMath {
    /// Drops samples older than `retention` relative to `now`. Boundary samples
    /// (exactly `retention` old) are kept. Input order is preserved.
    public static func pruned(
        _ samples: [UsageSample],
        now: Date,
        retention: TimeInterval = 43_200
    ) -> [UsageSample] {
        let cutoff = now.addingTimeInterval(-retention)
        return samples.filter { $0.timestamp >= cutoff }
    }

    /// Whether enough time has passed since the last recorded sample to record
    /// another. Records when there is no prior sample, or `now` is at least
    /// `interval` seconds after it.
    public static func shouldRecord(
        lastAt: Date?,
        now: Date,
        interval: TimeInterval = 60
    ) -> Bool {
        guard let lastAt else { return true }
        return now.timeIntervalSince(lastAt) >= interval
    }

    /// The sample closest in time to `date`, or `nil` for an empty buffer.
    public static func nearestSample(in samples: [UsageSample], to date: Date) -> UsageSample? {
        samples.min { a, b in
            abs(a.timestamp.timeIntervalSince(date)) < abs(b.timestamp.timeIntervalSince(date))
        }
    }
}
