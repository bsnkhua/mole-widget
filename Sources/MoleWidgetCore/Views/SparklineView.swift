import SwiftUI

/// A compact line graph that plots recent sample values as a single stroke.
/// With 0 or 1 values the view renders nothing — it fills in within seconds.
public struct SparklineView: View, Equatable {
    let values: [Double]
    let color: Color

    public init(values: [Double], color: Color) {
        self.values = values
        self.color = color
    }

    public var body: some View {
        GeometryReader { geo in
            Path { path in
                guard values.count > 1 else { return }
                let maxValue = max(values.max() ?? 0, 1e-9)
                let stepX = geo.size.width / CGFloat(values.count - 1)
                for (i, v) in values.enumerated() {
                    let x = CGFloat(i) * stepX
                    let y = geo.size.height * (1 - CGFloat(v / maxValue))
                    if i == 0 { path.move(to: CGPoint(x: x, y: y)) }
                    else { path.addLine(to: CGPoint(x: x, y: y)) }
                }
            }
            .stroke(color, style: StrokeStyle(lineWidth: 1.5, lineCap: .round, lineJoin: .round))
        }
        .frame(height: 12)
    }
}
