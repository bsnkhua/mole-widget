import Foundation

/// One menu bar metric: a short label and its formatted value, rendered as a
/// two-line column (label on top, value below) to save horizontal space.
public struct MenuBarMetric: Equatable {
    public let label: String
    public let value: String

    public init(label: String, value: String) {
        self.label = label
        self.value = value
    }
}

/// Builds the live menu bar metrics.
///
/// Uses a tight format (integer percent, integer degrees). An enabled metric
/// whose value is `nil` is omitted entirely — this keeps the menu bar clean at
/// startup and on Macs without a given sensor. An empty result means the caller
/// should fall back to the icon.
public enum MenuBarText {
    /// - Parameters:
    ///   - cpuFraction: `MetricsStore.cpu?.totalUsage`, range 0...1.
    ///   - memFraction: `MetricsStore.memory?.usedFraction`, range 0...1.
    ///   - temperatureC: `MetricsStore.cpuTemperature` (SoC die temperature).
    /// - Returns: e.g. `[CPU/42%, MEM/34%, TEMP/54°]`, empty when nothing to show.
    public static func metrics(
        cpuFraction: Double?,
        memFraction: Double?,
        temperatureC: Double?,
        showCPU: Bool,
        showMemory: Bool,
        showTemp: Bool
    ) -> [MenuBarMetric] {
        var result: [MenuBarMetric] = []
        if showCPU, let cpuFraction {
            result.append(MenuBarMetric(label: "CPU", value: percent(cpuFraction)))
        }
        if showMemory, let memFraction {
            result.append(MenuBarMetric(label: "MEM", value: percent(memFraction)))
        }
        if showTemp, let temperatureC {
            result.append(MenuBarMetric(label: "TEMP", value: degrees(temperatureC)))
        }
        return result
    }

    private static func percent(_ fraction: Double) -> String {
        "\(Int((fraction * 100).rounded()))%"
    }

    private static func degrees(_ celsius: Double) -> String {
        "\(Int(celsius.rounded()))°"
    }
}
