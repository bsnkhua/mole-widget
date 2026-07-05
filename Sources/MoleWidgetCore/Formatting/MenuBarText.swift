import Foundation

/// Builds the compact live-metrics string shown in the menu bar.
///
/// The menu bar has little room, so this uses a tighter format than `Fmt`
/// (integer percent, integer degrees). An enabled metric whose value is `nil`
/// is omitted entirely — this keeps the menu bar clean at startup and on Macs
/// without a battery (no temperature sensor). Returns `nil` when nothing is
/// enabled or no enabled metric has data yet, so the caller shows the icon.
public enum MenuBarText {
    /// - Parameters:
    ///   - cpuFraction: `MetricsStore.cpu?.totalUsage`, range 0...1.
    ///   - memFraction: `MetricsStore.memory?.usedFraction`, range 0...1.
    ///   - batteryTempC: `MetricsStore.power?.temperatureCelsius`.
    /// - Returns: e.g. `"CPU 42%  MEM 34%  TEMP 31°"`, or `nil` when there is
    ///   nothing to show.
    public static func compose(
        cpuFraction: Double?,
        memFraction: Double?,
        batteryTempC: Double?,
        showCPU: Bool,
        showMemory: Bool,
        showTemp: Bool
    ) -> String? {
        var parts: [String] = []
        if showCPU, let cpuFraction {
            parts.append("CPU " + percent(cpuFraction))
        }
        if showMemory, let memFraction {
            parts.append("MEM " + percent(memFraction))
        }
        if showTemp, let batteryTempC {
            parts.append("TEMP " + degrees(batteryTempC))
        }
        return parts.isEmpty ? nil : parts.joined(separator: "  ")
    }

    private static func percent(_ fraction: Double) -> String {
        "\(Int((fraction * 100).rounded()))%"
    }

    private static func degrees(_ celsius: Double) -> String {
        "\(Int(celsius.rounded()))°"
    }
}
