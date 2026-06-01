@testable import SlotKit
import Testing

struct SymbolThemeTests {
    @Test
    func defaultThemeCarriesNoSymbolsAndNoJackpot() {
        #expect(SlotTheme.default.symbols.isEmpty)
        #expect(SlotTheme.default.jackpotIndex == nil)
    }

    @Test
    func makeKeepsSymbolsAndJackpotIndex() throws {
        let theme = try Fixtures.symbolTheme()
        #expect(theme.symbols.count == 3)
        #expect(theme.jackpotIndex == 0)
    }

    @Test
    func withInheritsSymbolFieldsFromBaseTheme() throws {
        let base = try Fixtures.symbolTheme()
        let derived = try base.with { $0.minSpin = 0.5 }
        #expect(derived.symbols == base.symbols)
        #expect(derived.jackpotIndex == base.jackpotIndex)
    }

    @Test(arguments: [3, -1, 99])
    func jackpotIndexOutOfRangeThrows(badIndex: Int) throws {
        #expect(throws: SlotThemeError.self) {
            try SlotTheme.make { draft in
                draft.cellWidth = 3
                draft.cellHeight = 1
                draft.win = SlotSymbol(rows: ["WIN"])
                draft.lose = SlotSymbol(rows: ["los"])
                draft.spinning = [SlotSymbol(rows: ["..."])]
                draft.symbols = [SlotSymbol(rows: [" 7 "]), SlotSymbol(rows: [" C "])]
                draft.jackpotIndex = badIndex
            }
        }
    }

    @Test
    func mismatchedSymbolDimensionThrows() {
        #expect(throws: SlotThemeError.self) {
            try SlotTheme.make { draft in
                draft.cellWidth = 3
                draft.cellHeight = 1
                draft.win = SlotSymbol(rows: ["WIN"])
                draft.lose = SlotSymbol(rows: ["los"])
                draft.spinning = [SlotSymbol(rows: ["..."])]
                draft.symbols = [SlotSymbol(rows: ["TOO WIDE"])] // not cellWidth = 3
            }
        }
    }

    @Test
    func emptySymbolsWithNilJackpotIsValid() throws {
        let theme = try SlotTheme.make { draft in
            draft.cellWidth = 3
            draft.cellHeight = 1
            draft.win = SlotSymbol(rows: ["WIN"])
            draft.lose = SlotSymbol(rows: ["los"])
            draft.spinning = [SlotSymbol(rows: ["..."])]
        }
        #expect(theme.symbols.isEmpty)
        #expect(theme.jackpotIndex == nil)
    }
}
