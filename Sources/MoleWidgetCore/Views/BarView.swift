import SwiftUI

/// Horizontal progress bar: filled portion on a dimmed track.
public struct BarView: View, Equatable {
    let fraction: Double
    var color: Color?

    public init(fraction: Double, color: Color? = nil) {
        self.fraction = fraction
        self.color = color
    }

    public var body: some View {
        let clamped = min(max(fraction, 0), 1)
        GeometryReader { geo in
            ZStack(alignment: .leading) {
                Rectangle()
                    .fill(Theme.dim.opacity(0.25))
                Rectangle()
                    .fill(color ?? Theme.barColor(for: clamped))
                    .frame(width: geo.size.width * clamped)
            }
        }
        .frame(height: 10)
    }
}
