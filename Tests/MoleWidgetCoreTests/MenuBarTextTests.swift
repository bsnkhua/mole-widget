import Foundation
import Testing
@testable import MoleWidgetCore

@Suite struct MenuBarTextTests {
    private let gb = UInt64(1_073_741_824)

    @Test func allTogglesOff_returnsNil() {
        #expect(MenuBarText.compose(
            cpuFraction: 0.5, memUsedBytes: 8 * gb, batteryTempC: 30,
            showCPU: false, showMemory: false, showTemp: false
        ) == nil)
    }

    @Test func singleMetric_cpuOnly() {
        #expect(MenuBarText.compose(
            cpuFraction: 0.42, memUsedBytes: nil, batteryTempC: nil,
            showCPU: true, showMemory: false, showTemp: false
        ) == "C 42%")
    }

    @Test func allThree() {
        let text = MenuBarText.compose(
            cpuFraction: 0.423, memUsedBytes: 18 * gb + gb / 3, batteryTempC: 31.4,
            showCPU: true, showMemory: true, showTemp: true
        )
        #expect(text == "C 42% M 18.3G 31°")
    }

    @Test func enabledButNilData_showsPlaceholders() {
        #expect(MenuBarText.compose(
            cpuFraction: nil, memUsedBytes: nil, batteryTempC: nil,
            showCPU: true, showMemory: true, showTemp: true
        ) == "C -- M -- --°")
    }

    @Test func cpuPercent_rounds() {
        #expect(MenuBarText.compose(
            cpuFraction: 0.005, memUsedBytes: nil, batteryTempC: nil,
            showCPU: true, showMemory: false, showTemp: false
        ) == "C 1%")
        #expect(MenuBarText.compose(
            cpuFraction: 0.004, memUsedBytes: nil, batteryTempC: nil,
            showCPU: true, showMemory: false, showTemp: false
        ) == "C 0%")
    }

    @Test func tempOnly_rounds() {
        #expect(MenuBarText.compose(
            cpuFraction: nil, memUsedBytes: nil, batteryTempC: 30.6,
            showCPU: false, showMemory: false, showTemp: true
        ) == "31°")
    }
}
