import Foundation
import Testing
@testable import MoleWidgetCore

@Suite struct WidgetSettingsTests {
    @Test func clampWidth() {
        #expect(WidgetSettings.clampWidth(100) == WidgetSettings.minWidth)
        #expect(WidgetSettings.clampWidth(10_000) == WidgetSettings.maxWidth)
        #expect(WidgetSettings.clampWidth(600) == 600)
        #expect(WidgetSettings.clampWidth(WidgetSettings.minWidth) == WidgetSettings.minWidth)
        #expect(WidgetSettings.clampWidth(WidgetSettings.maxWidth) == WidgetSettings.maxWidth)
    }

    @Test func clampOpacity_belowMin_returnsMin() {
        #expect(WidgetSettings.clampOpacity(0.0) == 0.3)
        #expect(WidgetSettings.clampOpacity(-1.0) == 0.3)
    }

    @Test func clampOpacity_aboveMax_returnsMax() {
        #expect(WidgetSettings.clampOpacity(1.5) == 1.0)
        #expect(WidgetSettings.clampOpacity(2.0) == 1.0)
    }

    @Test func clampOpacity_midValue_passesThrough() {
        #expect(WidgetSettings.clampOpacity(0.92) == 0.92)
        #expect(WidgetSettings.clampOpacity(0.7) == 0.7)
        #expect(WidgetSettings.clampOpacity(0.3) == 0.3)
        #expect(WidgetSettings.clampOpacity(1.0) == 1.0)
    }

    @Test func clampFontSize_belowMin_returnsMin() {
        #expect(WidgetSettings.clampFontSize(8) == 11)
        #expect(WidgetSettings.clampFontSize(0) == 11)
    }

    @Test func clampFontSize_aboveMax_returnsMax() {
        #expect(WidgetSettings.clampFontSize(20) == 16)
        #expect(WidgetSettings.clampFontSize(100) == 16)
    }

    @Test func clampFontSize_inRange_passesThrough() {
        #expect(WidgetSettings.clampFontSize(11) == 11)
        #expect(WidgetSettings.clampFontSize(12) == 12)
        #expect(WidgetSettings.clampFontSize(14) == 14)
        #expect(WidgetSettings.clampFontSize(16) == 16)
    }

    @Test func resolveFontStyle_validRaw_returnsMatch() {
        #expect(WidgetSettings.resolveFontStyle("system") == .system)
        #expect(WidgetSettings.resolveFontStyle("monospaced") == .monospaced)
    }

    @Test func resolveFontStyle_invalidOrNil_defaultsToMonospaced() {
        #expect(WidgetSettings.resolveFontStyle("garbage") == .monospaced)
        #expect(WidgetSettings.resolveFontStyle(nil) == .monospaced)
        #expect(WidgetSettings.resolveFontStyle("") == .monospaced)
    }

    @Test func isVisible_absentKey_defaultsToVisible() {
        let suite = "WidgetSettingsTests.isVisible_absent"
        let defaults = UserDefaults(suiteName: suite)!
        defaults.removePersistentDomain(forName: suite)
        #expect(WidgetSettings.isVisible(in: defaults) == true)
    }

    @Test func isVisible_storedValue_isHonored() {
        let suite = "WidgetSettingsTests.isVisible_stored"
        let defaults = UserDefaults(suiteName: suite)!
        defaults.removePersistentDomain(forName: suite)
        defaults.set(false, forKey: WidgetSettings.widgetVisibleKey)
        #expect(WidgetSettings.isVisible(in: defaults) == false)
        defaults.set(true, forKey: WidgetSettings.widgetVisibleKey)
        #expect(WidgetSettings.isVisible(in: defaults) == true)
    }
}
