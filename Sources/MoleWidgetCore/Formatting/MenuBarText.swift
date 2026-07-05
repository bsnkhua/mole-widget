import Foundation

/// Builds the compact live-metrics string shown in the menu bar.
///
/// The menu bar has little room, so this uses a tighter format than `Fmt`
/// (integer percent, one-decimal gigabytes, integer degrees). Enabled metrics
/// whose data is not yet available render as `--` placeholders; when no metric
/// is enabled the function returns `nil` so the caller falls back to the icon.
public enum MenuBarText {
    /// - Parameters:
    ///   - cpuFraction: `MetricsStore.cpu?.totalUsage`, range 0...1.
    ///   - memUsedBytes: `MetricsStore.memory?.used`.
    ///   - batteryTempC: `MetricsStore.power?.temperatureCelsius`.
    /// - Returns: e.g. `"C 42% M 18.3G 31°"`, or `nil` when nothing is enabled.
    public static func compose(
        cpuFraction: Double?,
        memUsedBytes: UInt64?,
        batteryTempC: Double?,
        showCPU: Bool,
        showMemory: Bool,
        showTemp: Bool
    ) -> String? {
        guard showCPU || showMemory || showTemp else { return nil }

        var parts: [String] = []
        if showCPU {
            parts.append("C " + (cpuFraction.map(percent) ?? placeholder))
        }
        if showMemory {
            parts.append("M " + (memUsedBytes.map(gigabytes) ?? placeholder))
        }
        if showTemp {
            parts.append(batteryTempC.map(degrees) ?? "\(placeholder)°")
        }
        return parts.joined(separator: " ")
    }

    private static let placeholder = "--"

    private static func percent(_ fraction: Double) -> String {
        "\(Int((fraction * 100).rounded()))%"
    }

    private static func gigabytes(_ bytes: UInt64) -> String {
        String(format: "%.1fG", Double(bytes) / 1_073_741_824.0)
    }

    private static func degrees(_ celsius: Double) -> String {
        "\(Int(celsius.rounded()))°"
    }
}
