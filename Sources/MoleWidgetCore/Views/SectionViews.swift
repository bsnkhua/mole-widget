import SwiftUI

public struct CPUSectionView: View {
    let snapshot: CPUSnapshot?

    public init(snapshot: CPUSnapshot?) {
        self.snapshot = snapshot
    }

    public var body: some View {
        SectionView(icon: "◉", title: "CPU") {
            if let s = snapshot {
                MetricRow(label: "Total", fraction: s.totalUsage, value: Fmt.percent(s.totalUsage))
                ForEach(s.topCores, id: \.index) { core in
                    MetricRow(
                        label: "Core\(core.index + 1)",
                        fraction: core.usage,
                        value: Fmt.percent(core.usage)
                    )
                }
                if s.loadAverage.count >= 3 {
                    // ", N cores" did not fit in the column and was truncated — removed
                    TextRow(
                        label: "Load",
                        value: String(
                            format: "%.2f / %.2f / %.2f",
                            s.loadAverage[0], s.loadAverage[1], s.loadAverage[2]
                        )
                    )
                }
            } else {
                Text("No data").foregroundStyle(Theme.dim)
            }
        }
    }
}

public struct MemorySectionView: View {
    let snapshot: MemorySnapshot?

    public init(snapshot: MemorySnapshot?) {
        self.snapshot = snapshot
    }

    public var body: some View {
        SectionView(icon: "▥", title: "Memory") {
            if let s = snapshot {
                MetricRow(label: "Used", fraction: s.usedFraction, value: Fmt.percent(s.usedFraction))
                MetricRow(
                    label: "Free",
                    fraction: s.freeFraction,
                    value: Fmt.percent(s.freeFraction),
                    barColor: Theme.accent // high free memory is good — always green
                )
                TextRow(label: "Total", value: "\(Fmt.gigabytes(s.used)) / \(Fmt.gigabytes(s.total))")
                TextRow(label: "Cached", value: Fmt.gigabytes(s.cached))
                TextRow(label: "Avail", value: Fmt.gigabytes(s.available))
            } else {
                Text("No data").foregroundStyle(Theme.dim)
            }
        }
    }
}

public struct DiskSectionView: View {
    let usage: DiskUsageSnapshot?
    let io: DiskIORates?

    public init(usage: DiskUsageSnapshot?, io: DiskIORates?) {
        self.usage = usage
        self.io = io
    }

    public var body: some View {
        SectionView(icon: "▦", title: "Disk") {
            if usage == nil && io == nil {
                Text("No data").foregroundStyle(Theme.dim)
            } else {
                if let u = usage {
                    MetricRow(label: "Usage", fraction: u.usedFraction, value: Fmt.percent(u.usedFraction))
                    TextRow(label: "Total", value: "\(Fmt.gigabytes(u.total)) · \(u.fileSystem)")
                    TextRow(label: "Space", value: Fmt.usedFreePair(used: u.used, free: u.free))
                }
                if let io {
                    TextRow(label: "Speed", value: Fmt.readWritePair(read: io.read, write: io.write))
                }
            }
        }
    }
}

public struct NetworkSectionView: View {
    let rates: NetIORates?
    let info: NetworkInfo?

    public init(rates: NetIORates?, info: NetworkInfo?) {
        self.rates = rates
        self.info = info
    }

    public var body: some View {
        SectionView(icon: "⇅", title: "Network") {
            if rates == nil && info == nil {
                Text("No data").foregroundStyle(Theme.dim)
            } else {
                if let r = rates {
                    TextRow(label: "Down", value: Fmt.rate(r.download))
                    TextRow(label: "Up", value: Fmt.rate(r.upload))
                }
                if let i = info {
                    TextRow(label: "Iface", value: ifaceString(i))
                }
            }
        }
    }

    private func ifaceString(_ i: NetworkInfo) -> String {
        if let ip = i.localIP { return "\(i.interfaceName) · \(ip)" }
        return i.interfaceName
    }
}

public struct PowerSectionView: View {
    let snapshot: PowerSnapshot?

    public init(snapshot: PowerSnapshot?) {
        self.snapshot = snapshot
    }

    public var body: some View {
        SectionView(icon: "◪", title: "Power") {
            if let s = snapshot {
                MetricRow(
                    label: "Level",
                    fraction: s.levelFraction,
                    value: Fmt.percent(s.levelFraction),
                    barColor: levelColor(s.levelFraction)
                )
                if let health = s.healthFraction {
                    MetricRow(
                        label: "Health",
                        fraction: health,
                        value: Fmt.percent(health),
                        barColor: Theme.accent
                    )
                }
                TextRow(label: "Status", value: statusLine(s))
                if let detail = detailLine(s) {
                    TextRow(label: "Battery", value: detail)
                }
            } else {
                Text("No data").foregroundStyle(Theme.dim)
            }
        }
    }

    private func levelColor(_ level: Double) -> Color {
        switch level {
        case ..<0.2: Theme.danger
        case ..<0.5: Theme.warning
        default: Theme.accent
        }
    }

    private func statusLine(_ s: PowerSnapshot) -> String {
        let state = s.isCharging ? "Charging" : "Discharging"
        guard let minutes = s.timeRemainingMinutes else { return state }
        return "\(state) · \(BatteryMath.formatMinutes(minutes))"
    }

    private func detailLine(_ s: PowerSnapshot) -> String? {
        var parts: [String] = []
        if let cycles = s.cycleCount { parts.append("\(cycles) cycles") }
        if let t = s.temperatureCelsius { parts.append(String(format: "%.1f°C", t)) }
        return parts.isEmpty ? nil : parts.joined(separator: " · ")
    }
}
