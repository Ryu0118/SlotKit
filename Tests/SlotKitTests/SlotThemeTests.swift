@testable import SlotKit
import Testing

struct SlotThemeValidationTests {
    @Test
    func defaultThemeBuildsWithConsistentDimensions() {
        let theme = SlotTheme.default
        #expect(theme.cellWidth == 10)
        #expect(theme.cellHeight == 5)
        for symbol in theme.spinning + [theme.win, theme.lose] {
            #expect(symbol.rows.count == theme.cellHeight)
            for row in symbol.rows {
                #expect(row.count == theme.cellWidth)
            }
        }
    }

    @Test
    func wrongRowCountThrows() {
        #expect(throws: SlotThemeError.self) {
            try SlotTheme.make { draft in
                draft.cellWidth = 3
                draft.cellHeight = 2
                draft.win = SlotSymbol(rows: ["abc"]) // 1 row, expected 2
                draft.lose = SlotSymbol(rows: ["abc", "def"])
                draft.spinning = [SlotSymbol(rows: ["abc", "def"])]
            }
        }
    }

    @Test
    func wrongRowWidthThrows() {
        #expect(throws: SlotThemeError.self) {
            try SlotTheme.make { draft in
                draft.cellWidth = 3
                draft.cellHeight = 1
                draft.win = SlotSymbol(rows: ["abcd"]) // 4 wide, expected 3
                draft.lose = SlotSymbol(rows: ["abc"])
                draft.spinning = [SlotSymbol(rows: ["abc"])]
            }
        }
    }

    @Test
    func noSpinningSymbolsThrows() {
        #expect(throws: SlotThemeError.noSpinningSymbols) {
            try SlotTheme.make { draft in
                draft.cellWidth = 3
                draft.cellHeight = 1
                draft.win = SlotSymbol(rows: ["abc"])
                draft.lose = SlotSymbol(rows: ["abc"])
                draft.spinning = []
            }
        }
    }

    @Test
    func withDerivesFromBaseKeepingUntouchedFields() throws {
        // A small tweak inherits everything else from `.default` and stays valid.
        let derived = try SlotTheme.default.with { draft in
            draft.minSpin = 0
            draft.frameInterval = 0.02
        }
        #expect(derived.minSpin == 0)
        #expect(derived.frameInterval == 0.02)
        // Untouched fields carry over from the base.
        #expect(derived.cellWidth == SlotTheme.default.cellWidth)
        #expect(derived.cellHeight == SlotTheme.default.cellHeight)
        #expect(derived.spinning.count == SlotTheme.default.spinning.count)
    }

    @Test
    func withRevalidatesAndThrowsOnBrokenDimensions() {
        // Changing cellWidth without resizing the inherited 10-wide symbols must throw —
        // proves `with` re-validates the derived result instead of trusting the base.
        #expect(throws: SlotThemeError.self) {
            try SlotTheme.default.with { draft in
                draft.cellWidth = 7
            }
        }
    }
}
