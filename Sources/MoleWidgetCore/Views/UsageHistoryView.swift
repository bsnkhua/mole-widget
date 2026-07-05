import Charts
import SwiftUI

/// Retrospective window: CPU and RAM usage over the retained history with a
/// hover/click scrubber. Selecting a point shows the heaviest processes
/// recorded at that moment — the "what was the laptop stuck on?" view.
public struct UsageHistoryView: View {
    let history: UsageHistoryStore

    @State private var selectedDate: Date?
    @State private var range: TimeRange = .fourHours

    public init(history: UsageHistoryStore) {
        self.history = history
    }

    /// How far back the chart shows. Retention is 12 h; narrowing the view
    /// spreads points out so peaks are easy to scrub to.
    private enum TimeRange: String, CaseIterable, Identifiable {
        case oneHour = "1h", fourHours = "4h", twelveHours = "12h"
        var id: String { rawValue }
        var seconds: TimeInterval {
            switch self {
            case .oneHour: 3_600
            case .fourHours: 14_400
            case .twelveHours: 43_200
            }
        }
    }

    /// Samples within the selected range, anchored to the newest sample so an
    /// idle gap doesn't push everything off the right edge.
    private var visibleSamples: [UsageSample] {
        guard let last = history.samples.last else { return [] }
        let cutoff = last.timestamp.addingTimeInterval(-range.seconds)
        return history.samples.filter { $0.timestamp >= cutoff }
    }

    public var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack {
                Text("Usage History")
                    .font(.headline)
                Spacer()
                Picker("Range", selection: $range) {
                    ForEach(TimeRange.allCases) { Text($0.rawValue).tag($0) }
                }
                .pickerStyle(.segmented)
                .fixedSize()
                .labelsHidden()
            }

            if history.samples.count < 2 {
                Spacer()
                Text("Collecting data — check back in a few minutes.")
                    .foregroundStyle(.secondary)
                    .frame(maxWidth: .infinity, alignment: .center)
                Spacer()
            } else {
                chart
                detailPane
            }
        }
        .padding(16)
        .frame(minWidth: 520, minHeight: 340)
    }

    private var chart: some View {
        Chart {
            ForEach(visibleSamples) { sample in
                LineMark(
                    x: .value("Time", sample.timestamp),
                    y: .value("Usage", sample.cpuFraction * 100),
                    series: .value("Metric", "CPU")
                )
                .foregroundStyle(Theme.accent)
            }
            ForEach(visibleSamples) { sample in
                LineMark(
                    x: .value("Time", sample.timestamp),
                    y: .value("Usage", sample.memFraction * 100),
                    series: .value("Metric", "Memory")
                )
                .foregroundStyle(Theme.header)
            }
            if let selectedDate {
                RuleMark(x: .value("Selected", selectedDate))
                    .foregroundStyle(.secondary.opacity(0.5))
            }
        }
        .chartYScale(domain: 0...100)
        .chartYAxisLabel("%")
        .chartForegroundStyleScale(["CPU": Theme.accent, "Memory": Theme.header])
        .chartXSelection(value: $selectedDate)
        .frame(minHeight: 200)
    }

    @ViewBuilder
    private var detailPane: some View {
        let selected = selectedDate.flatMap {
            UsageHistoryMath.nearestSample(in: visibleSamples, to: $0)
        } ?? visibleSamples.last

        if let sample = selected {
            VStack(alignment: .leading, spacing: 6) {
                HStack {
                    Text(sample.timestamp, style: .time)
                        .font(.subheadline).bold()
                    Text(sample.timestamp, style: .date)
                        .font(.subheadline).foregroundStyle(.secondary)
                    Spacer()
                    Text("CPU \(Int((sample.cpuFraction * 100).rounded()))%")
                        .foregroundStyle(Theme.accent)
                    Text("RAM \(Fmt.gigabytes(sample.memUsedBytes))")
                        .foregroundStyle(Theme.header)
                }

                if sample.topProcesses.isEmpty {
                    Text("No process data recorded.")
                        .font(.caption).foregroundStyle(.secondary)
                } else {
                    ForEach(sample.topProcesses, id: \.pid) { proc in
                        HStack {
                            Text(proc.name).lineLimit(1)
                            Spacer()
                            Text("\(Int((proc.cpuFraction * 100).rounded()))%")
                                .monospacedDigit().foregroundStyle(.secondary)
                            Text(Fmt.gigabytes(proc.memoryBytes))
                                .monospacedDigit().foregroundStyle(.secondary)
                                .frame(width: 70, alignment: .trailing)
                        }
                        .font(.caption)
                    }
                }
            }
        }
    }
}
