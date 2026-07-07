import Foundation
import Testing
@testable import MoleWidgetCore

@Suite struct MenuBarTextTests {
    private func pairs(_ metrics: [MenuBarMetric]) -> [String] {
        metrics.map { "\($0.label) \($0.value)" }
    }

    /// Builds an `enabled` predicate that is true only for the given kinds.
    private func on(_ kinds: MenuBarMetricKind...) -> (MenuBarMetricKind) -> Bool {
        let set = Set(kinds)
        return { set.contains($0) }
    }

    private let allOn: (MenuBarMetricKind) -> Bool = { _ in true }

    @Test func allTogglesOff_returnsEmpty() {
        let values = MenuBarValues(cpuFraction: 0.5, memFraction: 0.5, temperatureC: 30)
        #expect(MenuBarText.metrics(values) { _ in false }.isEmpty)
    }

    @Test func singleMetric_cpuOnly() {
        let values = MenuBarValues(cpuFraction: 0.42)
        #expect(pairs(MenuBarText.metrics(values, enabled: on(.cpu))) == ["CPU 42%"])
    }

    @Test func classicThree() {
        let values = MenuBarValues(cpuFraction: 0.423, memFraction: 0.34, temperatureC: 54.4)
        #expect(pairs(MenuBarText.metrics(values, enabled: on(.cpu, .memory, .temp)))
            == ["CPU 42%", "MEM 34%", "TEMP 54°"])
    }

    @Test func allEnabledButNoData_returnsEmpty() {
        #expect(MenuBarText.metrics(MenuBarValues(), enabled: allOn).isEmpty)
    }

    @Test func nilMetricIsOmitted() {
        // Temp enabled but absent → dropped, others remain.
        let values = MenuBarValues(cpuFraction: 0.42, memFraction: 0.34, temperatureC: nil)
        #expect(pairs(MenuBarText.metrics(values, enabled: on(.cpu, .memory, .temp)))
            == ["CPU 42%", "MEM 34%"])
    }

    @Test func cpuPercent_rounds() {
        #expect(pairs(MenuBarText.metrics(MenuBarValues(cpuFraction: 0.005), enabled: on(.cpu)))
            == ["CPU 1%"])
        #expect(pairs(MenuBarText.metrics(MenuBarValues(cpuFraction: 0.004), enabled: on(.cpu)))
            == ["CPU 0%"])
    }

    @Test func tempOnly_rounds() {
        #expect(pairs(MenuBarText.metrics(MenuBarValues(temperatureC: 30.6), enabled: on(.temp)))
            == ["TEMP 31°"])
    }

    @Test func network_isOneStackedMetric() {
        // 1 MiB/s down over 512 KiB/s up, combined into a single stacked column.
        let values = MenuBarValues(
            netDownBytesPerSec: 1_048_576,
            netUpBytesPerSec: 524_288
        )
        let metrics = MenuBarText.metrics(values, enabled: on(.network))
        #expect(metrics.count == 1)
        #expect(metrics[0].stacked)
        #expect(metrics[0].label == "↓ 1.0M")  // top line
        #expect(metrics[0].value == "↑ 0.5M")  // bottom line
    }

    @Test func network_needsBothDirections() {
        // Only one rate present → omitted (netRates is all-or-nothing in practice).
        #expect(MenuBarText.metrics(MenuBarValues(netDownBytesPerSec: 1_048_576),
                                    enabled: on(.network)).isEmpty)
    }

    @Test func disk_isOneStackedMetric() {
        let values = MenuBarValues(
            diskReadBytesPerSec: 2_097_152,
            diskWriteBytesPerSec: 1_048_576
        )
        let metrics = MenuBarText.metrics(values, enabled: on(.disk))
        #expect(metrics.count == 1)
        #expect(metrics[0].stacked)
        #expect(metrics[0].label == "R 2.0M")
        #expect(metrics[0].value == "W 1.0M")
    }

    @Test func canonicalOrder_regardlessOfEnableOrder() {
        // Everything on → fixed order cpu, memory, temp, network, disk.
        let values = MenuBarValues(
            cpuFraction: 0.1, memFraction: 0.2, temperatureC: 40,
            netDownBytesPerSec: 1_048_576, netUpBytesPerSec: 1_048_576,
            diskReadBytesPerSec: 1_048_576, diskWriteBytesPerSec: 1_048_576
        )
        let metrics = MenuBarText.metrics(values, enabled: allOn)
        #expect(metrics.count == 5)
        #expect(metrics.map(\.stacked) == [false, false, false, true, true])
        #expect(metrics[0].label == "CPU")
        #expect(metrics[3].label == "↓ 1.0M")   // network
        #expect(metrics[4].label == "R 1.0M")   // disk
    }
}
