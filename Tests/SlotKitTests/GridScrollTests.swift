@testable import SlotKit
import Testing

/// Verifies the scrolling reel renderer (``GridRenderer/scrollingFrame(_:theme:)``) and its
/// agreement with the skill-stop, without a TTY: the strip slides down one art row per step,
/// wraps cleanly, and at strip-aligned offsets shows whole faces equal to what the skill-stop
/// would land on (the single-source-of-truth invariant that keeps the hand stop WYSIWYG).
struct GridScrollTests {
    /// A scroll-mode theme whose faces are tall and each art row is a distinct token, so a
    /// one-row scroll is visible as a shifted set of tokens. `cellHeight = 2`.
    private static func tallTheme() throws -> SlotTheme {
        try SlotTheme.make { draft in
            draft.cellWidth = 3
            draft.cellHeight = 2
            draft.win = SlotSymbol(rows: ["WIN", "win"])
            draft.lose = SlotSymbol(rows: ["LOS", "los"])
            draft.spinning = [
                SlotSymbol(rows: ["A0=", "A1="]),
                SlotSymbol(rows: ["B0=", "B1="]),
                SlotSymbol(rows: ["C0=", "C1="]),
            ]
            draft.symbols = draft.spinning
            draft.jackpotIndex = 0
            draft.frameInterval = 0.001
            draft.minSpin = 0
            draft.colorize = SlotColorizers.plain
            draft.scrollSpin = true
        }
    }

    private static func input(_ theme: SlotTheme, rowOffset: Int, cols: Int = 1) -> GridRenderer.ScrollInput {
        GridRenderer.ScrollInput(
            spinning: theme.spinning,
            landedFaces: Array(repeating: nil, count: cols),
            rowOffset: rowOffset,
            rows: 1,
            labels: Array(repeating: nil, count: cols),
        )
    }

    /// Just the art lines (drop the top/bottom borders).
    private static func art(_ theme: SlotTheme, rowOffset: Int) -> [String] {
        Array(GridRenderer.scrollingFrame(input(theme, rowOffset: rowOffset), theme: theme).dropFirst().dropLast())
    }

    /// Incrementing `rowOffset` by one shifts the window down by exactly one art row: the
    /// bottom art row of frame n becomes the top art row of frame n+1.
    @Test
    func scrollShiftsDownOneArtRowPerStep() throws {
        let theme = try Self.tallTheme()
        for offset in 0 ..< (theme.spinning.count * theme.cellHeight) {
            #expect(Self.art(theme, rowOffset: offset + 1).first == Self.art(theme, rowOffset: offset).last)
        }
    }

    /// At strip-aligned offsets (`rowOffset` a multiple of `cellHeight`) the window shows a
    /// whole, un-split face — exactly the face `showingIndex` (and thus the skill-stop) reads.
    @Test
    func alignedOffsetMatchesShowingIndex() throws {
        let theme = try Self.tallTheme()
        let geometry = GridRenderer.ScrollGeometry(rows: 1, cellHeight: theme.cellHeight)
        for faceShift in 0 ..< theme.spinning.count {
            let offset = faceShift * theme.cellHeight
            let shownIndex = GridRenderer.showingIndex(
                spinningCount: theme.spinning.count,
                rowOffset: offset,
                column: 0,
                row: 0,
                geometry: geometry,
            )
            let face = theme.spinning[shownIndex]
            let art = Self.art(theme, rowOffset: offset)
            for artRow in 0 ..< theme.cellHeight {
                let expected = "║" + SlotRenderer.centered(face.rows[artRow], width: theme.cellWidth) + "║"
                #expect(art[artRow] == expected)
            }
        }
    }

    /// **The feature's core invariant.** A skill-stop at a strip-aligned step lands the column
    /// on exactly the faces `scrollingFrame` was showing — WYSIWYG. Drive a real `spinGridSkill`
    /// stop and assert the landed index equals `showingIndex` at that step.
    @Test
    func skillStopLandsOnTheShowingFace() async throws {
        let theme = try Self.tallTheme()
        let rows = 1
        let stepToStopAt = 4 // a multiple of cellHeight (2): an aligned frame
        let box = GridResultBox(columns: 2, rows: rows)
        // Drive the box to the stop step, then stop column 0.
        _ = await box.scrollState(step: stepToStopAt, theme: theme, labels: [nil, nil])
        await box.stopAtCurrentStep(0, theme: theme)
        let landed = await box.landedColumns()
        let geometry = GridRenderer.ScrollGeometry(rows: rows, cellHeight: theme.cellHeight)
        let expected = GridRenderer.showingIndex(
            spinningCount: theme.spinning.count,
            rowOffset: stepToStopAt,
            column: 0,
            row: 0,
            geometry: geometry,
        )
        #expect(landed[0][0] == expected)
    }

    /// A settled column draws its landed face statically regardless of `rowOffset`.
    @Test
    func settledColumnDoesNotScroll() throws {
        let theme = try Self.tallTheme()
        let landedFace = theme.spinning[1]
        func art(_ offset: Int) -> [String] {
            let input = GridRenderer.ScrollInput(
                spinning: theme.spinning,
                landedFaces: [[landedFace]],
                rowOffset: offset,
                rows: 1,
                labels: [nil],
            )
            return Array(GridRenderer.scrollingFrame(input, theme: theme).dropFirst().dropLast())
        }
        #expect(art(0) == art(3))
        for artRow in 0 ..< theme.cellHeight {
            let expected = "║" + SlotRenderer.centered(landedFace.rows[artRow], width: theme.cellWidth) + "║"
            #expect(art(7)[artRow] == expected)
        }
    }

    /// `stripArtRow` wraps cleanly: position `stripRows` returns the same as position 0.
    @Test
    func stripWrapsAround() throws {
        let theme = try Self.tallTheme()
        let strip = theme.spinning
        let stripRows = strip.count * theme.cellHeight
        for position in 0 ..< stripRows {
            #expect(
                GridRenderer.stripArtRow(strip, at: position, column: 0, rows: 1, cellHeight: theme.cellHeight)
                    == GridRenderer.stripArtRow(
                        strip,
                        at: position + stripRows,
                        column: 0,
                        rows: 1,
                        cellHeight: theme.cellHeight,
                    ),
            )
        }
    }
}
