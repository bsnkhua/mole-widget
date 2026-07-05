import SwiftUI

/// Terminal color palette in the spirit of `mo status` (Catppuccin-inspired pastels).
public enum Theme {
    public static let background = Color(red: 0.118, green: 0.133, blue: 0.188) // dark blue
    public static let header = Color(red: 0.792, green: 0.620, blue: 0.902)     // lavender
    public static let accent = Color(red: 0.651, green: 0.820, blue: 0.537)     // green
    public static let warning = Color(red: 0.898, green: 0.784, blue: 0.565)    // yellow
    public static let danger = Color(red: 0.906, green: 0.510, blue: 0.518)     // red
    public static let text = Color(red: 0.780, green: 0.800, blue: 0.870)       // light gray
    public static let dim = Color(red: 0.450, green: 0.470, blue: 0.550)        // muted

    /// Base widget font. Size and style are user-configurable; the monospaced
    /// style keeps column alignment, the system style reads more natively while
    /// `.monospacedDigit()` still stops numbers from jittering as they tick.
    public static func font(size: Double, style: WidgetSettings.FontStyle) -> Font {
        switch style {
        case .monospaced: Font.system(size: size, design: .monospaced).weight(.medium)
        case .system:     Font.system(size: size).weight(.medium).monospacedDigit()
        }
    }

    public static let font = font(size: WidgetSettings.defaultFontSize, style: .monospaced)

    /// Higher load maps to a more alarming color.
    public static func barColor(for fraction: Double) -> Color {
        switch fraction {
        case ..<0.6: accent
        case ..<0.85: warning
        default: danger
        }
    }
}
