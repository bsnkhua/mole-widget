import Foundation
import Testing
@testable import MoleWidgetCore

@Suite struct NetworkTests {
    @Test func ratesFromCounterDeltas() {
        let prev = NetIOCounters(bytesIn: 1000, bytesOut: 2000)
        let cur = NetIOCounters(bytesIn: 1000 + 2_097_152, bytesOut: 2000 + 1_048_576)
        let rates = NetIO.rates(previous: prev, current: cur, interval: 2.0)
        #expect(abs(rates.download - 1_048_576) < 0.1)
        #expect(abs(rates.upload - 524_288) < 0.1)
    }

    @Test func ratesIgnoreCounterReset() {
        let prev = NetIOCounters(bytesIn: 5000, bytesOut: 5000)
        let cur = NetIOCounters(bytesIn: 100, bytesOut: 6000)
        let rates = NetIO.rates(previous: prev, current: cur, interval: 1.0)
        #expect(rates.download == 0)
        #expect(rates.upload == 1000)
    }

    @Test func ratesWithZeroIntervalAreZero() {
        let c = NetIOCounters(bytesIn: 1, bytesOut: 1)
        let rates = NetIO.rates(previous: c, current: c, interval: 0)
        #expect(rates.download == 0)
        #expect(rates.upload == 0)
    }

    @Test func collectorReturnsCumulativeCounters() throws {
        let collector = NetworkCollector()
        let first = try #require(collector.ioCounters())
        #expect(first.bytesIn > 0) // any live Mac has received bytes
        Thread.sleep(forTimeInterval: 0.3)
        let second = try #require(collector.ioCounters())
        #expect(second.bytesIn >= first.bytesIn)
    }

    @Test func collectorReturnsNetworkInfoOnLiveMac() {
        // Interface info may be nil on a fully offline machine — just must not crash
        _ = NetworkCollector().info()
    }
}
