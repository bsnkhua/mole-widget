import Foundation

/// Value formatters matching the style of `mo status` output.
public enum Fmt {
    /// 17_179_869_184 → "16.0 GB"
    public static func gigabytes(_ bytes: UInt64) -> String {
        gigabytesNumber(bytes) + " GB"
    }

    /// Disk usage in mo style: "164G used · 297G free"
    public static func usedFreePair(used: UInt64, free: UInt64) -> String {
        "\(gigabytesCompact(used)) used · \(gigabytesCompact(free)) free"
    }

    /// Adaptive compact memory footprint: "1.5G" at or above 1 GiB, "793M"
    /// below. Avoids showing small processes as a misleading "0.0G".
    public static func memoryCompact(_ bytes: UInt64) -> String {
        let gib = Double(bytes) / 1_073_741_824.0
        if gib >= 1 { return String(format: "%.1fG", gib) }
        return String(format: "%.0fM", Double(bytes) / 1_048_576.0)
    }

    /// 0.119 → "11.9%"
    public static func percent(_ fraction: Double) -> String {
        String(format: "%.1f%%", fraction * 100)
    }

    /// Bytes/s → "0.5 MB/s"; above ~100 MB/s — no fractional part.
    /// Negative values (counter reset, sample race) are clamped to 0.
    public static func rate(_ bytesPerSecond: Double) -> String {
        rateNumber(bytesPerSecond) + " MB/s"
    }

    /// Disk read/write speeds: "R 0.1 · W 0.5 MB/s"
    public static func readWritePair(read: Double, write: Double) -> String {
        "R \(rateNumber(read)) · W \(rateNumber(write)) MB/s"
    }

    private static func gigabytesNumber(_ bytes: UInt64) -> String {
        String(format: "%.1f", Double(bytes) / 1_073_741_824.0)
    }

    /// "164G" (≥ 10 GiB — no fractional part), "5.0G" (< 10 GiB)
    private static func gigabytesCompact(_ bytes: UInt64) -> String {
        let gb = Double(bytes) / 1_073_741_824.0
        if gb >= 10 { return String(format: "%.0fG", gb) }
        return String(format: "%.1fG", gb)
    }

    private static func rateNumber(_ bytesPerSecond: Double) -> String {
        let mbps = max(0, bytesPerSecond) / 1_048_576.0
        if mbps >= 99.95 { return String(format: "%.0f", mbps.rounded()) }
        return String(format: "%.1f", mbps)
    }
}
