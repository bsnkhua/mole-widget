import SwiftUI

/// Mini version of the app icon: four rounded bars of varying length.
/// Bar proportions mirror the menu bar glyph (14 / 9 / 11.8 / 5.5,
/// see `MoleWidgetApp.menuBarIcon`).
struct TitleGlyphView: View {
    /// Bar lengths relative to the longest bar.
    private static let relativeWidths: [CGFloat] = [1.0, 0.64, 0.84, 0.39]
    private let barHeight: CGFloat = 2.0
    private let gap: CGFloat = 1.0
    private let maxWidth: CGFloat = 11.0

    var body: some View {
        VStack(alignment: .leading, spacing: gap) {
            ForEach(Array(Self.relativeWidths.enumerated()), id: \.offset) { _, fraction in
                RoundedRectangle(cornerRadius: barHeight / 2)
                    .frame(width: maxWidth * fraction, height: barHeight)
            }
        }
        .foregroundStyle(Theme.header)
    }
}
