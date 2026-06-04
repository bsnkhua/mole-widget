import Foundation
import Testing
@testable import MoleWidgetCore

@Suite struct ProcessTests {

    // MARK: - ProcessMath unit tests

    @Test func topNormalTwoProcessCase() {
        // interval = 2.0 s, proc A consumed 2e9 ns → 1.0 core, proc B consumed 1e9 ns → 0.5 core
        let prev = [
            ProcSample(pid: 1, name: "procA", cpuTimeNs: 0,          memoryBytes: 0),
            ProcSample(pid: 2, name: "procB", cpuTimeNs: 0,          memoryBytes: 0),
        ]
        let cur = [
            ProcSample(pid: 1, name: "procA", cpuTimeNs: 2_000_000_000, memoryBytes: 100),
            ProcSample(pid: 2, name: "procB", cpuTimeNs: 1_000_000_000, memoryBytes: 200),
        ]
        let result = ProcessMath.top(previous: prev, current: cur, interval: 2.0, count: 3)
        #expect(result.count == 2)
        #expect(result[0].name == "procA")
        #expect(abs(result[0].cpuFraction - 1.0) < 0.001)
        #expect(result[0].memoryBytes == 100)
        #expect(result[1].name == "procB")
        #expect(abs(result[1].cpuFraction - 0.5) < 0.001)
        #expect(result[1].memoryBytes == 200)
    }

    @Test func topNewPidSkipped() {
        // pid 99 is not in previous → must be skipped
        let prev = [
            ProcSample(pid: 1, name: "old", cpuTimeNs: 0, memoryBytes: 0),
        ]
        let cur = [
            ProcSample(pid: 1,  name: "old", cpuTimeNs: 1_000_000_000, memoryBytes: 50),
            ProcSample(pid: 99, name: "new", cpuTimeNs: 5_000_000_000, memoryBytes: 80),
        ]
        let result = ProcessMath.top(previous: prev, current: cur, interval: 1.0, count: 3)
        #expect(result.count == 1)
        #expect(result[0].name == "old")
    }

    @Test func topVanishedPidSkipped() {
        // pid 2 exists in previous but not in current → must be skipped
        let prev = [
            ProcSample(pid: 1, name: "alive",  cpuTimeNs: 0, memoryBytes: 0),
            ProcSample(pid: 2, name: "zombie", cpuTimeNs: 0, memoryBytes: 0),
        ]
        let cur = [
            ProcSample(pid: 1, name: "alive", cpuTimeNs: 1_000_000_000, memoryBytes: 50),
        ]
        let result = ProcessMath.top(previous: prev, current: cur, interval: 1.0, count: 3)
        #expect(result.count == 1)
        #expect(result[0].name == "alive")
    }

    @Test func topZeroIntervalReturnsEmpty() {
        let prev = [ProcSample(pid: 1, name: "a", cpuTimeNs: 0,          memoryBytes: 0)]
        let cur  = [ProcSample(pid: 1, name: "a", cpuTimeNs: 1_000_000_000, memoryBytes: 0)]
        let result = ProcessMath.top(previous: prev, current: cur, interval: 0, count: 3)
        #expect(result.isEmpty)
    }

    @Test func topCountLimit() {
        // 5 processes, count = 2 → only top-2 returned
        let prev = (1...5).map { ProcSample(pid: Int32($0), name: "p\($0)", cpuTimeNs: 0, memoryBytes: 0) }
        let cur  = (1...5).map { i -> ProcSample in
            ProcSample(pid: Int32(i), name: "p\(i)", cpuTimeNs: UInt64(i) * 1_000_000_000, memoryBytes: 0)
        }
        let result = ProcessMath.top(previous: prev, current: cur, interval: 1.0, count: 2)
        #expect(result.count == 2)
        // pid 5 has the highest CPU time
        #expect(result[0].name == "p5")
        #expect(result[1].name == "p4")
    }

    @Test func topTieOrderByPidAscending() {
        // Two processes with identical cpuFraction → lower pid must come first
        let prev = [
            ProcSample(pid: 10, name: "alpha", cpuTimeNs: 0, memoryBytes: 0),
            ProcSample(pid: 5,  name: "beta",  cpuTimeNs: 0, memoryBytes: 0),
        ]
        let cur = [
            ProcSample(pid: 10, name: "alpha", cpuTimeNs: 1_000_000_000, memoryBytes: 0),
            ProcSample(pid: 5,  name: "beta",  cpuTimeNs: 1_000_000_000, memoryBytes: 0),
        ]
        let result = ProcessMath.top(previous: prev, current: cur, interval: 1.0, count: 3)
        #expect(result.count == 2)
        #expect(result[0].name == "beta")  // pid 5 < pid 10
        #expect(result[1].name == "alpha")
    }

    @Test func topNegativeDeltaClampedToZero() {
        // cpuTimeNs regressed (should not happen but guard it): delta must be clamped to 0
        let prev = [ProcSample(pid: 1, name: "a", cpuTimeNs: 5_000_000_000, memoryBytes: 0)]
        let cur  = [ProcSample(pid: 1, name: "a", cpuTimeNs: 1_000_000_000, memoryBytes: 0)]
        let result = ProcessMath.top(previous: prev, current: cur, interval: 1.0, count: 3)
        #expect(result.count == 1)
        #expect(result[0].cpuFraction == 0.0)
    }

    // MARK: - ProcessCollector smoke test

    @Test func collectorSmokeTest() throws {
        let collector = ProcessCollector()
        let first = collector.sample()
        #expect(!first.isEmpty)

        Thread.sleep(forTimeInterval: 0.3)
        let second = collector.sample()

        let results = ProcessMath.top(previous: first, current: second, interval: 0.3, count: 3)
        #expect(results.count >= 1)
        #expect(results.count <= 3)
        for p in results {
            #expect(p.cpuFraction >= 0)
            #expect(!p.name.isEmpty)
        }
    }
}
