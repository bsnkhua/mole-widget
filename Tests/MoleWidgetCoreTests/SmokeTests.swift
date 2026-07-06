import Testing
@testable import MoleWidgetCore

@Suite struct SmokeTests {
    @Test func version() {
        #expect(CoreInfo.version == "0.8.2")
    }
}
