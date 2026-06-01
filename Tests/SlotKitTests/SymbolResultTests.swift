@testable import SlotKit
import Testing

struct SymbolResultTests {
    private static func result(_ indices: [Int], jackpotIndex: Int?) -> SymbolSpinResult {
        SymbolSpinResult(
            outcomes: indices.enumerated().map { position, landedIndex in
                SymbolOutcome(label: "\(position)", landedIndex: landedIndex)
            },
            jackpotIndex: jackpotIndex,
        )
    }

    @Test(arguments: [
        ([0, 0, 0], true),
        ([2, 2], true),
        ([0, 1, 0], false),
        ([1], true), // a single reel is trivially "all the same"
        ([], false), // an empty spin is not a win line
    ])
    func allSameReflectsEveryReelMatching(indices: [Int], expected: Bool) {
        #expect(Self.result(indices, jackpotIndex: 0).allSame == expected)
    }

    @Test(arguments: [
        ([0, 0, 0], 0, true), // every reel on the jackpot index
        ([1, 1, 1], 0, false), // all-same, but not the jackpot symbol
        ([0, 0, 1], 0, false), // mixed
        ([2, 2], 2, true), // jackpot can be any index
        ([0, 0], nil, false), // no jackpot configured → never a jackpot
        ([], 0, false), // empty spin
    ])
    func isJackpotRequiresEveryReelOnTheJackpotIndex(indices: [Int], jackpotIndex: Int?, expected: Bool) {
        #expect(Self.result(indices, jackpotIndex: jackpotIndex).isJackpot == expected)
    }

    @Test
    func jackpotImpliesAllSame() {
        let result = Self.result([0, 0, 0], jackpotIndex: 0)
        #expect(result.isJackpot)
        #expect(result.allSame)
    }
}
