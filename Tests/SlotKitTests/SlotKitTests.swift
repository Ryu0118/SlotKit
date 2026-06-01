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

struct SlotRendererTests {
    private func makeTheme() throws -> SlotTheme {
        try SlotTheme.make { draft in
            draft.cellWidth = 3
            draft.cellHeight = 1
            draft.win = SlotSymbol(rows: ["WWW"])
            draft.lose = SlotSymbol(rows: ["LLL"])
            draft.spinning = [SlotSymbol(rows: ["..."])]
        }
    }

    @Test
    func frameLaysOutBordersArtAndLabels() throws {
        let theme = try makeTheme()
        let lines = SlotRenderer.frame(
            symbols: [SlotSymbol(rows: ["WWW"]), SlotSymbol(rows: ["LLL"])],
            labels: ["A", "B"],
            theme: theme,
        )
        // top + 1 art row + bottom + label row = 4 lines.
        #expect(lines.count == 4)
        #expect(lines[0] == "╔═══╗╔═══╗")
        #expect(lines[1] == "║WWW║║LLL║")
        #expect(lines[2] == "╚═══╝╚═══╝")
        // labels centered in cellWidth + 2 (= 5) columns each.
        #expect(lines[3] == "  A    B  ")
    }

    @Test
    func everyLineSharesWidth() throws {
        let theme = try makeTheme()
        let lines = SlotRenderer.frame(
            symbols: [SlotSymbol(rows: ["WWW"]), SlotSymbol(rows: ["..."])],
            labels: ["X", "Y"],
            theme: theme,
        )
        let widths = Set(lines.map(\.count))
        #expect(widths.count == 1)
    }

    @Test
    func centeredClipsOverlongText() {
        #expect(SlotRenderer.centered("toolong", width: 3) == "too")
        #expect(SlotRenderer.centered("x", width: 5) == "  x  ")
    }
}

struct SlotColorizerTests {
    @Test
    func plainIsIdentity() {
        #expect(SlotColorizers.plain("hello", 0) == "hello")
        #expect(SlotColorizers.plain("a b c", 42) == "a b c")
    }

    @Test
    func rainbowWrapsAnsiButKeepsCharacters() {
        let colored = SlotColorizers.rainbow("hi", 0)
        #expect(colored.contains("\u{1B}["))
        #expect(colored.contains("h"))
        #expect(colored.contains("i"))
        #expect(colored.hasSuffix("\u{1B}[0m"))
    }

    @Test
    func rainbowLeavesSpacesUncolored() {
        // A run of only spaces should come back unchanged (plus the trailing reset).
        let colored = SlotColorizers.rainbow("   ", 0)
        #expect(colored == "   \u{1B}[0m")
    }
}

struct SlotMachineTests {
    @Test
    func plainSpinRunsChecksAndReportsOutcomes() async {
        let reels = [
            SlotReel(label: "A") { true },
            SlotReel(label: "B") { false },
            SlotReel(label: "C") { throw CancellationError() },
        ]
        let result = await SlotMachine.spin(reels, plain: true)
        #expect(result.outcomes == [
            SlotOutcome(label: "A", passed: true),
            SlotOutcome(label: "B", passed: false),
            SlotOutcome(label: "C", passed: false),
        ])
        #expect(!result.allPassed)
    }

    @Test
    func allPassedWhenEveryReelWins() async {
        let reels = [
            SlotReel(label: "A") { true },
            SlotReel(label: "B") { true },
        ]
        let result = await SlotMachine.spin(reels, plain: true)
        #expect(result.allPassed)
    }

    @Test
    func emptyReelsReturnEmptyResult() async {
        let result = await SlotMachine.spin([], plain: true)
        #expect(result.outcomes.isEmpty)
        #expect(result.allPassed) // vacuously true
    }
}
