@testable import SlotKit
import Testing

/// Verifies per-column spinning strips (``SlotTheme/spinningStrips``): each reel scrolls its own
/// sequence of faces, the skill-stop lands on exactly the face that column was showing
/// (per-lane WYSIWYG), and an empty `spinningStrips` is byte-identical to the shared ``spinning``.
struct GridPerColumnStripTests {
    /// `cellHeight = 2`, three columns each with a DISTINCT strip so a column landing on the
    /// wrong strip is detectable. Column 0's faces start with "A", column 1 with "B", column 2
    /// with "C" — no face token appears in more than one column's strip.
    private static func perColumnTheme() throws -> SlotTheme {
        func strip(_ prefix: String, _ count: Int) -> [SlotSymbol] {
            (0 ..< count).map { SlotSymbol(rows: ["\(prefix)\($0)0", "\(prefix)\($0)1"]) }
        }
        return try SlotTheme.make { draft in
            draft.cellWidth = 3
            draft.cellHeight = 2
            draft.win = SlotSymbol(rows: ["WIN", "win"])
            draft.lose = SlotSymbol(rows: ["LOS", "los"])
            draft.spinning = strip("Z", 3) // the shared fallback, unused when strips are set
            draft.symbols = strip("A", 2) + strip("B", 3) + strip("C", 4)
            draft.spinningStrips = [strip("A", 2), strip("B", 3), strip("C", 4)]
            draft.frameInterval = 0.001
            draft.minSpin = 0
            draft.colorize = SlotColorizers.plain
            draft.scrollSpin = true
        }
    }

    /// **The feature's core invariant.** For every column, a skill-stop at an aligned step lands
    /// the column on exactly the faces `scrollingFrame` was showing for THAT column's strip —
    /// per-lane WYSIWYG. A column that landed on the shared `spinning` or another column's strip
    /// would fail (token prefixes differ per column).
    @Test
    func skillStopLandsOnEachColumnsOwnStrip() async throws {
        let theme = try Self.perColumnTheme()
        let rows = 1
        let stepToStopAt = 2 // a multiple of cellHeight (2): an aligned frame
        let box = GridResultBox(columns: 3, rows: rows)
        _ = await box.scrollState(step: stepToStopAt, theme: theme, labels: [nil, nil, nil])
        for column in 0 ..< 3 {
            await box.stopAtCurrentStep(column, theme: theme)
        }
        let landed = await box.landedColumns()
        for column in 0 ..< 3 {
            let strip = theme.strip(forColumn: column)
            let geometry = GridRenderer.ScrollGeometry(rows: rows, cellHeight: theme.cellHeight)
            let expected = GridRenderer.showingIndex(
                spinningCount: strip.count,
                rowOffset: stepToStopAt,
                column: column,
                row: 0,
                geometry: geometry,
            )
            let landedFace = theme.symbols[landed[column][0]]
            #expect(landedFace == strip[expected], "column \(column) landed off its own strip")
        }
    }

    /// The scrolling render of each column uses that column's strip: the art rows shown for a
    /// column come from its strip, never the shared `spinning` or a neighbour's.
    @Test
    func eachColumnScrollsItsOwnStrip() throws {
        let theme = try Self.perColumnTheme()
        let input = GridRenderer.ScrollInput(
            spinning: theme.spinning,
            landedFaces: [nil, nil, nil],
            rowOffset: 0,
            rows: 1,
            labels: [nil, nil, nil],
        )
        let lines = GridRenderer.scrollingFrame(input, theme: theme)
        // Art rows are lines 1...cellHeight (after the top border). Each cell is "║xxx║".
        let firstArt = lines[1]
        // Column 0 shows an "A" face, column 1 a "B" face, column 2 a "C" face.
        #expect(firstArt.contains("A"))
        #expect(firstArt.contains("B"))
        #expect(firstArt.contains("C"))
    }

    /// An empty `spinningStrips` resolves every column to the shared `spinning` — the default,
    /// byte-identical to a theme that never set strips.
    @Test
    func emptyStripsFallBackToSharedSpinning() throws {
        let theme = try SlotTheme.make { draft in
            draft.cellWidth = 3
            draft.cellHeight = 1
            draft.win = SlotSymbol(rows: ["WIN"])
            draft.lose = SlotSymbol(rows: ["los"])
            draft.spinning = [SlotSymbol(rows: ["..."]), SlotSymbol(rows: ["oOo"])]
            draft.colorize = SlotColorizers.plain
        }
        #expect(theme.spinningStrips.isEmpty)
        for column in 0 ..< 5 {
            #expect(theme.strip(forColumn: column) == theme.spinning)
        }
    }

    /// A short `spinningStrips` covers any column count by wrapping (modulo).
    @Test
    func stripsWrapToCoverMoreColumns() throws {
        let theme = try Self.perColumnTheme() // 3 strips
        #expect(theme.strip(forColumn: 0) == theme.strip(forColumn: 3))
        #expect(theme.strip(forColumn: 1) == theme.strip(forColumn: 4))
    }

    /// An empty strip in `spinningStrips` is rejected at build time (it would divide by zero
    /// when the scroll position wraps).
    @Test
    func emptyStripIsRejected() {
        #expect(throws: SlotThemeError.emptySpinningStrip(column: 1)) {
            try SlotTheme.make { draft in
                draft.cellWidth = 3
                draft.cellHeight = 1
                draft.win = SlotSymbol(rows: ["WIN"])
                draft.lose = SlotSymbol(rows: ["los"])
                draft.spinning = [SlotSymbol(rows: ["..."])]
                draft.spinningStrips = [[SlotSymbol(rows: ["..."])], [], [SlotSymbol(rows: ["oOo"])]]
                draft.colorize = SlotColorizers.plain
            }
        }
    }
}
