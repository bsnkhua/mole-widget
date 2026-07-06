import Foundation
import Testing
@testable import MoleWidgetCore

@Suite struct MenuBarTextTests {
    private func pairs(_ metrics: [MenuBarMetric]) -> [String] {
        metrics.map { "\($0.label) \($0.value)" }
    }

    @Test func allTogglesOff_returnsEmpty() {
        #expect(MenuBarText.metrics(
            cpuFraction: 0.5, memFraction: 0.5, temperatureC: 30,
            showCPU: false, showMemory: false, showTemp: false
        ).isEmpty)
    }

    @Test func singleMetric_cpuOnly() {
        #expect(pairs(MenuBarText.metrics(
            cpuFraction: 0.42, memFraction: nil, temperatureC: nil,
            showCPU: true, showMemory: false, showTemp: false
        )) == ["CPU 42%"])
    }

    @Test func allThree() {
        #expect(pairs(MenuBarText.metrics(
            cpuFraction: 0.423, memFraction: 0.34, temperatureC: 54.4,
            showCPU: true, showMemory: true, showTemp: true
        )) == ["CPU 42%", "MEM 34%", "TEMP 54°"])
    }

    @Test func allEnabledButNoData_returnsEmpty() {
        #expect(MenuBarText.metrics(
            cpuFraction: nil, memFraction: nil, temperatureC: nil,
            showCPU: true, showMemory: true, showTemp: true
        ).isEmpty)
    }

    @Test func nilMetricIsOmitted() {
        // Temp enabled but absent → dropped, others remain.
        #expect(pairs(MenuBarText.metrics(
            cpuFraction: 0.42, memFraction: 0.34, temperatureC: nil,
            showCPU: true, showMemory: true, showTemp: true
        )) == ["CPU 42%", "MEM 34%"])
    }

    @Test func cpuPercent_rounds() {
        #expect(pairs(MenuBarText.metrics(
            cpuFraction: 0.005, memFraction: nil, temperatureC: nil,
            showCPU: true, showMemory: false, showTemp: false
        )) == ["CPU 1%"])
        #expect(pairs(MenuBarText.metrics(
            cpuFraction: 0.004, memFraction: nil, temperatureC: nil,
            showCPU: true, showMemory: false, showTemp: false
        )) == ["CPU 0%"])
    }

    @Test func tempOnly_rounds() {
        #expect(pairs(MenuBarText.metrics(
            cpuFraction: nil, memFraction: nil, temperatureC: 30.6,
            showCPU: false, showMemory: false, showTemp: true
        )) == ["TEMP 31°"])
    }
}
