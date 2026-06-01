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
}
