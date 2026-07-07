import Testing
@testable import MoleWidgetCore

@Suite struct SMCTemperatureTests {
    @Test func aggregate_empty_returnsNil() {
        #expect(SMCTemperature.aggregate([]) == nil)
    }

    @Test func aggregate_normalSet_returnsMedian() {
        // Odd count → middle value.
        #expect(SMCTemperature.aggregate([44, 46, 48]) == 46)
        // Even count → mean of the two middle values.
        #expect(SMCTemperature.aggregate([44, 46, 48, 50]) == 47)
    }

    @Test func aggregate_singleOutlier_isIgnored() {
        // A lone hot sensor near the 130° filter edge must not drag the figure up.
        let result = SMCTemperature.aggregate([45, 46, 47, 125])
        #expect(result != nil)
        #expect(abs(result! - 46.5) < 0.001)
        #expect(result! < 100)
    }

    @Test func aggregate_allImplausiblyHigh_returnsNil() {
        // Whole set above the plausibility ceiling → unreliable → dropped.
        #expect(SMCTemperature.aggregate([115, 118, 120]) == nil)
    }

    @Test func aggregate_atCeiling_isKept() {
        #expect(SMCTemperature.aggregate([110]) == 110)
    }
}
