import Foundation

/// Shared widget settings (UserDefaults keys and bounds).
public enum WidgetSettings {
    // MARK: - Position / size

    /// Pins the widget: blocks both dragging and resizing.
    public static let positionLockedKey = "positionLocked"

    /// User-adjustable widget width (points).
    public static let widgetWidthKey = "widgetWidth"

    /// Below this width the longest text rows start wrapping.
    public static let minWidth: Double = 490
    public static let maxWidth: Double = 880
    public static let defaultWidth: Double = 520

    public static func clampWidth(_ width: Double) -> Double {
        min(max(width, minWidth), maxWidth)
    }

    // MARK: - Background opacity

    public static let backgroundOpacityKey = "backgroundOpacity"
    public static let defaultOpacity: Double = 0.92

    /// Clamps opacity to the allowed range [0.3, 1.0].
    public static func clampOpacity(_ opacity: Double) -> Double {
        min(max(opacity, 0.3), 1.0)
    }

    // MARK: - Refresh rate

    public static let refreshIntervalKey = "refreshInterval"
    public static let defaultRefreshInterval: Double = 2.0

    // MARK: - Section visibility

    public static let showHeaderKey    = "showHeader"
    public static let showCPUKey       = "showCPU"
    public static let showMemoryKey    = "showMemory"
    public static let showDiskKey      = "showDisk"
    public static let showPowerKey     = "showPower"
    public static let showNetworkKey   = "showNetwork"
    public static let showProcessesKey = "showProcesses"

    // MARK: - Desktop visibility

    /// Whether the widget window is shown on the desktop. Hiding it keeps the
    /// app and its menu bar icon running so the widget can be summoned again.
    public static let widgetVisibleKey = "widgetVisible"
    public static let defaultVisible = true

    /// Resolves desktop visibility from the given defaults. An absent key reads
    /// as `defaultVisible` (visible); `UserDefaults.bool(forKey:)` on its own
    /// returns false for an absent key, which would wrongly start the widget
    /// hidden on a fresh install.
    public static func isVisible(in defaults: UserDefaults) -> Bool {
        defaults.object(forKey: widgetVisibleKey) == nil
            ? defaultVisible
            : defaults.bool(forKey: widgetVisibleKey)
    }
}
