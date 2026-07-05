import SwiftUI

public struct CPUSectionView: View, Equatable {
    let snapshot: CPUSnapshot?
    let history: [Double]
    let temperature: Double?

    public init(snapshot: CPUSnapshot?, history: [Double], temperature: Double?) {
        self.snapshot = snapshot
        self.history = history
        self.temperature = temperature
    }

    public var body: some View {
        SectionView(icon: "◉", title: "CPU") {
            if let s = snapshot {
                MetricRow(label: "Total", fraction: s.totalUsage, value: Fmt.percent(s.totalUsage))
                if let temperature {
                    TextRow(label: "Temp", value: String(format: "%.0f°C", temperature))
                }
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
                HStack(spacing: 8) {
                    Text("Trend")
                        .foregroundStyle(Theme.text)
                        .frame(width: 56, alignment: .leading)
                    SparklineView(values: history, color: Theme.accent)
                }
            } else {
                Text("No data").foregroundStyle(Theme.dim)
            }
        }
    }
}

public struct MemorySectionView: View, Equatable {
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

public struct DiskSectionView: View, Equatable {
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

public struct NetworkSectionView: View, Equatable {
    let rates: NetIORates?
    let info: NetworkInfo?
    let downloadHistory: [Double]
    let uploadHistory: [Double]

    public init(rates: NetIORates?, info: NetworkInfo?, downloadHistory: [Double] = [], uploadHistory: [Double] = []) {
        self.rates = rates
        self.info = info
        self.downloadHistory = downloadHistory
        self.uploadHistory = uploadHistory
    }

    public var body: some View {
        SectionView(icon: "⇅", title: "Network") {
            if rates == nil && info == nil {
                Text("No data").foregroundStyle(Theme.dim)
            } else {
                if let r = rates {
                    SparkRow(label: "Down", values: downloadHistory, value: Fmt.rate(r.download), color: Theme.accent)
                    SparkRow(label: "Up", values: uploadHistory, value: Fmt.rate(r.upload), color: Theme.header)
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

public struct PowerSectionView: View, Equatable {
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

public struct ProcessesSectionView: View, Equatable {
    let processes: [ProcessUsage]

    public init(processes: [ProcessUsage]) {
        self.processes = processes
    }

    public var body: some View {
        SectionView(icon: "≡", title: "Processes") {
            if processes.isEmpty {
                Text("No data").foregroundStyle(Theme.dim)
            } else {
                ForEach(processes.prefix(3), id: \.pid) { p in
                    // Process names vary wildly in length; give the name the
                    // flexible space and let SwiftUI truncate with "…" —
                    // a single line always, so the row height never jumps.
                    HStack(spacing: 8) {
                        Text(p.name)
                            .foregroundStyle(Theme.text)
                            .lineLimit(1)
                            .truncationMode(.tail)
                        Spacer(minLength: 8)
                        Text(valueString(p))
                            .foregroundStyle(Theme.text)
                            .lineLimit(1)
                            .fixedSize()
                    }
                }
            }
        }
    }

    private func valueString(_ p: ProcessUsage) -> String {
        let cpuPct = String(format: "%.0f%%", p.cpuFraction * 100)
        let memGb = String(format: "%.1fG", Double(p.memoryBytes) / 1_073_741_824.0)
        return "\(cpuPct) · \(memGb)"
    }
}
