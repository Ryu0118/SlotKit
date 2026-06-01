@testable import SlotKit

/// Shared test fixtures.
enum Fixtures {
    /// A small, instantly-resolving theme for animated-path tests: `minSpin = 0` and a tiny
    /// frame interval so `spin(_, plain: false)` returns without real-time delay, plus a
    /// finale so the all-win path exercises the flourish branch.
    static func fastTheme() throws -> SlotTheme {
        try SlotTheme.make { draft in
            draft.cellWidth = 3
            draft.cellHeight = 1
            draft.win = SlotSymbol(rows: ["WIN"])
            draft.lose = SlotSymbol(rows: ["los"])
            draft.spinning = [SlotSymbol(rows: ["..."]), SlotSymbol(rows: ["oOo"])]
            draft.frameInterval = 0.001
            draft.minSpin = 0
            draft.colorize = SlotColorizers.plain
            draft.finale = SlotTheme.SlotFinale(frames: 2, interval: 0.001)
            draft.bust = SlotTheme.SlotFinale(frames: 2, interval: 0.001)
        }
    }

    /// A small, instantly-resolving theme for the symbol path: three landing faces
    /// (`7` / `C` / `B`), `jackpotIndex = 0` (the `7`), `minSpin = 0` and a tiny frame
    /// interval so `spinSymbols(_, plain: false)` returns without real-time delay.
    static func symbolTheme() throws -> SlotTheme {
        try SlotTheme.make { draft in
            draft.cellWidth = 3
            draft.cellHeight = 1
            draft.win = SlotSymbol(rows: ["WIN"])
            draft.lose = SlotSymbol(rows: ["los"])
            draft.spinning = [SlotSymbol(rows: ["..."]), SlotSymbol(rows: ["oOo"])]
            draft.symbols = [SlotSymbol(rows: [" 7 "]), SlotSymbol(rows: [" C "]), SlotSymbol(rows: [" B "])]
            draft.jackpotIndex = 0
            draft.frameInterval = 0.001
            draft.minSpin = 0
            draft.colorize = SlotColorizers.plain
            draft.finale = SlotTheme.SlotFinale(frames: 2, interval: 0.001)
            draft.bust = SlotTheme.SlotFinale(frames: 2, interval: 0.001)
        }
    }
}
