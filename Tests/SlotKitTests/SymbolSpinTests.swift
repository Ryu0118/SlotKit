@testable import SlotKit
import Testing

struct SymbolSpinTests {
    @Test
    func plainSpinReportsEachReelsLandedIndex() async throws {
        let theme = try Fixtures.symbolTheme()
        let reels = [
            SymbolReel(label: "A") { 0 },
            SymbolReel(label: "B") { 1 },
            SymbolReel(label: "C") { 2 },
        ]
        let result = await SlotMachine.spinSymbols(reels, theme: theme, plain: true)
        #expect(result.outcomes == [
            SymbolOutcome(label: "A", landedIndex: 0),
            SymbolOutcome(label: "B", landedIndex: 1),
            SymbolOutcome(label: "C", landedIndex: 2),
        ])
    }

    @Test
    func plainSpinCarriesTheThemesJackpotIndex() async throws {
        let theme = try Fixtures.symbolTheme() // jackpotIndex = 0
        let result = await SlotMachine.spinSymbols([SymbolReel { 0 }], theme: theme, plain: true)
        #expect(result.jackpotIndex == 0)
    }

    @Test
    func plainSpinDetectsAJackpotLine() async throws {
        let theme = try Fixtures.symbolTheme()
        let reels = [SymbolReel { 0 }, SymbolReel { 0 }, SymbolReel { 0 }]
        let result = await SlotMachine.spinSymbols(reels, theme: theme, plain: true)
        #expect(result.isJackpot)
        #expect(result.allSame)
    }

    @Test
    func plainSpinDetectsANonJackpotWinLine() async throws {
        let theme = try Fixtures.symbolTheme()
        let reels = [SymbolReel { 1 }, SymbolReel { 1 }]
        let result = await SlotMachine.spinSymbols(reels, theme: theme, plain: true)
        #expect(result.allSame)
        #expect(!result.isJackpot)
    }

    @Test
    func plainSpinDetectsAMixedLine() async throws {
        let theme = try Fixtures.symbolTheme()
        let reels = [SymbolReel { 0 }, SymbolReel { 1 }, SymbolReel { 0 }]
        let result = await SlotMachine.spinSymbols(reels, theme: theme, plain: true)
        #expect(!result.allSame)
        #expect(!result.isJackpot)
    }

    @Test
    func emptyReelsReturnEmptyResult() async throws {
        let theme = try Fixtures.symbolTheme()
        let result = await SlotMachine.spinSymbols([], theme: theme, plain: true)
        #expect(result.outcomes.isEmpty)
        #expect(!result.allSame)
        #expect(!result.isJackpot)
    }

    @Test
    func unlabeledReelCarriesNilLabelThroughToOutcome() async throws {
        let theme = try Fixtures.symbolTheme()
        let result = await SlotMachine.spinSymbols([SymbolReel { 1 }], theme: theme, plain: true)
        #expect(result.outcomes.map(\.label) == [nil])
        #expect(result.outcomes.map(\.landedIndex) == [1])
    }
}

struct SymbolSpinAnimatedTests {
    @Test
    func animatedJackpotReportsEveryReelOnTheJackpotIndex() async throws {
        let theme = try Fixtures.symbolTheme()
        let reels = [SymbolReel(label: "A") { 0 }, SymbolReel(label: "B") { 0 }]
        let result = await SlotMachine.spinSymbols(reels, theme: theme, plain: false)
        #expect(result.isJackpot)
        #expect(result.outcomes.map(\.label) == ["A", "B"])
    }

    @Test
    func animatedMixedLineReportsPerReelLandedIndices() async throws {
        let theme = try Fixtures.symbolTheme()
        let reels = [SymbolReel(label: "A") { 0 }, SymbolReel(label: "B") { 2 }]
        let result = await SlotMachine.spinSymbols(reels, theme: theme, plain: false)
        #expect(!result.allSame)
        #expect(result.outcomes == [
            SymbolOutcome(label: "A", landedIndex: 0),
            SymbolOutcome(label: "B", landedIndex: 2),
        ])
    }

    @Test
    func animatedPathPreservesReelOrder() async throws {
        // Reels resolve at staggered times; the result must stay in input order.
        let theme = try Fixtures.symbolTheme()
        let reels = [
            SymbolReel(label: "SLOW") {
                try? await Task.sleep(for: .milliseconds(30))
                return 0
            },
            SymbolReel(label: "FAST") { 1 },
        ]
        let result = await SlotMachine.spinSymbols(reels, theme: theme, plain: false)
        #expect(result.outcomes.map(\.label) == ["SLOW", "FAST"])
        #expect(result.outcomes.map(\.landedIndex) == [0, 1])
    }

    @Test
    func cancellationPropagatesToReelsOnAnimatedPath() async throws {
        // Symbol-path analogue of the Bool-path cancellation regression: a long draw must
        // unwind promptly when the awaiting task is cancelled.
        let theme = try Fixtures.symbolTheme()
        let observedCancellation = ObservedFlag()
        let reels = [
            SymbolReel(label: "SLOW") {
                do {
                    try await Task.sleep(for: .seconds(60))
                } catch {
                    await observedCancellation.set()
                    return 0
                }
                return 0
            },
        ]

        let task = Task { await SlotMachine.spinSymbols(reels, theme: theme, plain: false) }
        try? await Task.sleep(for: .milliseconds(50))
        task.cancel()
        _ = await task.value

        #expect(await observedCancellation.value)
    }

    private actor ObservedFlag {
        private(set) var value = false
        func set() {
            value = true
        }
    }
}
