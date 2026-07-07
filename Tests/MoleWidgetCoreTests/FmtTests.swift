import Testing
@testable import MoleWidgetCore

@Suite struct FmtTests {
    @Test func gigabytes() {
        #expect(Fmt.gigabytes(17_179_869_184) == "16.0 GB")
        #expect(Fmt.gigabytes(10_630_044_058) == "9.9 GB")
        #expect(Fmt.gigabytes(0) == "0.0 GB")
    }

    @Test func memoryCompact() {
        #expect(Fmt.memoryCompact(1_610_612_736) == "1.5G")   // 1.5 GiB
        #expect(Fmt.memoryCompact(1_073_741_824) == "1.0G")   // exactly 1 GiB
        #expect(Fmt.memoryCompact(831_472_640) == "793M")     // 793 MiB
        #expect(Fmt.memoryCompact(5_242_880) == "5M")         // 5 MiB
        #expect(Fmt.memoryCompact(0) == "0M")
    }

    @Test func percent() {
        #expect(Fmt.percent(0.119) == "11.9%")
        #expect(Fmt.percent(1.0) == "100.0%")
        #expect(Fmt.percent(0) == "0.0%")
    }

    @Test func rate() {
        #expect(Fmt.rate(524_288) == "0.5 MB/s")
        #expect(Fmt.rate(0) == "0.0 MB/s")
        #expect(Fmt.rate(157_286_400) == "150 MB/s") // >= 100 MB/s — no fractional part
        #expect(Fmt.rate(-1_048_576) == "0.0 MB/s")  // negative delta → 0
        #expect(Fmt.rate(104_857_599) == "100 MB/s") // 99.999 MB/s — no format flicker
        #expect(Fmt.rate(47_185_920) == "45.0 MB/s") // mid range
    }

    @Test func rateCompact() {
        #expect(Fmt.rateCompact(524_288) == "0.5M")
        #expect(Fmt.rateCompact(0) == "0.0M")
        #expect(Fmt.rateCompact(157_286_400) == "150M") // >= 100 MB/s — no fractional part
        #expect(Fmt.rateCompact(-1_048_576) == "0.0M")  // negative delta → 0
    }

    @Test func usedFreePair() {
        // ≥ 10 GiB — no fractional part (mo style: "164G")
        #expect(Fmt.usedFreePair(used: 175_973_534_106, free: 318_372_188_979) == "164G used · 297G free")
        // < 10 GiB — one decimal digit
        #expect(Fmt.usedFreePair(used: 5_368_709_120, free: 17_179_869_184) == "5.0G used · 16G free")
        #expect(Fmt.usedFreePair(used: 0, free: 0) == "0.0G used · 0.0G free")
    }

    @Test func readWritePair() {
        #expect(Fmt.readWritePair(read: 104_858, write: 524_288) == "R 0.1 · W 0.5 MB/s")
        #expect(Fmt.readWritePair(read: 0, write: 0) == "R 0.0 · W 0.0 MB/s")
        #expect(Fmt.readWritePair(read: -1, write: 157_286_400) == "R 0.0 · W 150 MB/s")
    }
}
