import AppKit
import SwiftUI

/// Widget section: "● CPU ························" header + content.
/// Clicking the header title opens Activity Monitor; the tap area is limited
/// to the icon + title so window dragging from the rest of the section works.
public struct SectionView<Content: View>: View {
    let icon: String
    let title: String
    @ViewBuilder let content: Content

    public init(icon: String, title: String, @ViewBuilder content: () -> Content) {
        self.icon = icon
        self.title = title
        self.content = content()
    }

    public var body: some View {
        VStack(alignment: .leading, spacing: 4) {
            HStack(spacing: 6) {
                HStack(spacing: 6) {
                    Text(icon).foregroundStyle(Theme.header)
                    Text(title).bold().foregroundStyle(Theme.header)
                }
                .contentShape(Rectangle())
                .onTapGesture { Self.openActivityMonitor() }
                .help("Open Activity Monitor")
                DottedLine()
            }
            content
        }
    }

    static func openActivityMonitor() {
        let url = URL(fileURLWithPath: "/System/Applications/Utilities/Activity Monitor.app")
        NSWorkspace.shared.openApplication(at: url, configuration: .init()) { _, error in
            if let error {
                NSLog("mole-widget: failed to open Activity Monitor: \(error.localizedDescription)")
            }
        }
    }
}

/// Dotted filler line in the section header.
struct DottedLine: View {
    var body: some View {
        GeometryReader { geo in
            Path { p in
                p.move(to: CGPoint(x: 0, y: geo.size.height / 2))
                p.addLine(to: CGPoint(x: geo.size.width, y: geo.size.height / 2))
            }
            .stroke(Theme.dim.opacity(0.5), style: StrokeStyle(lineWidth: 1, dash: [1, 3]))
        }
        .frame(height: 10)
    }
}

/// Row with "label — bar — value" layout.
struct MetricRow: View, Equatable {
    let label: String
    let fraction: Double
    let value: String
    var barColor: Color?

    init(label: String, fraction: Double, value: String, barColor: Color? = nil) {
        self.label = label
        self.fraction = fraction
        self.value = value
        self.barColor = barColor
    }

    var body: some View {
        // lineLimit(1) everywhere: a wrapped row changes the widget height
        HStack(spacing: 8) {
            Text(label)
                .foregroundStyle(Theme.text)
                .lineLimit(1)
                .frame(width: 56, alignment: .leading)
            BarView(fraction: fraction, color: barColor).equatable()
            Text(value)
                .foregroundStyle(Theme.text)
                .lineLimit(1)
                .frame(width: 56, alignment: .trailing)
        }
    }
}

/// Row with "label — text" layout, no bar.
struct TextRow: View {
    let label: String
    let value: String

    var body: some View {
        HStack(spacing: 8) {
            Text(label)
                .foregroundStyle(Theme.text)
                .lineLimit(1)
                .frame(width: 56, alignment: .leading)
            Text(value)
                .foregroundStyle(Theme.text)
                .lineLimit(1)
                .truncationMode(.tail)
            Spacer(minLength: 0)
        }
    }
}

/// Row with a label, a sparkline of recent history, and a trailing value.
struct SparkRow: View, Equatable {
    let label: String
    let values: [Double]
    let value: String
    let color: Color

    var body: some View {
        HStack(spacing: 8) {
            Text(label)
                .foregroundStyle(Theme.text)
                .lineLimit(1)
                .frame(width: 56, alignment: .leading)
            SparklineView(values: values, color: color).equatable()
            Text(value)
                .foregroundStyle(Theme.text)
                .lineLimit(1)
                .fixedSize()
                .frame(minWidth: 56, alignment: .trailing)
        }
    }
}
