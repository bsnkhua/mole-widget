import Foundation

/// Pure math: top-N processes by CPU fraction from two consecutive samples.
public enum ProcessMath {

    /// Returns up to `count` processes sorted by CPU fraction (descending).
    /// Tie-break: lower pid first (stable ordering for the UI).
    ///
    /// - Only pids present in *both* samples are included.
    /// - cpuFraction = deltaNs / (interval × 1e9); 1.0 == one full core.
    /// - Negative deltas (counter reset or sampling anomaly) are clamped to 0.
    /// - Returns an empty array when interval <= 0.
    public static func top(
        previous: [ProcSample],
        current: [ProcSample],
        interval: TimeInterval,
        count: Int = 3
    ) -> [ProcessUsage] {
        guard interval > 0 else { return [] }

        // Build a lookup from pid → previous sample for O(n) join.
        let prevMap: [Int32: ProcSample] = Dictionary(
            previous.map { ($0.pid, $0) },
            uniquingKeysWith: { first, _ in first }
        )

        let intervalNs = interval * 1_000_000_000

        var rows: [ProcessUsage] = []
        rows.reserveCapacity(current.count)

        for sample in current {
            guard let prev = prevMap[sample.pid] else { continue } // new pid → skip
            let deltaNs = sample.cpuTimeNs >= prev.cpuTimeNs
                ? sample.cpuTimeNs - prev.cpuTimeNs
                : 0 // counter regressed — clamp to 0
            rows.append(ProcessUsage(
                pid: sample.pid,
                name: sample.name,
                cpuFraction: Double(deltaNs) / intervalNs,
                memoryBytes: sample.memoryBytes
            ))
        }

        // Sort by cpuFraction desc; tie → lower pid first.
        let sorted = rows.sorted {
            if $0.cpuFraction != $1.cpuFraction {
                return $0.cpuFraction > $1.cpuFraction
            }
            return $0.pid < $1.pid
        }

        return Array(sorted.prefix(count))
    }
}
