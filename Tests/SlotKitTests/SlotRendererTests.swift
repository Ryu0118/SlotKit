@testable import SlotKit
import Testing

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

    @Test
    func lineCountMatchesFrameOutput() throws {
        // SSoT guard: the count the animation loop uses to reposition the cursor must
        // equal the lines `frame` actually emits, so layout edits can't silently desync.
        let theme = try makeTheme()
        let lines = SlotRenderer.frame(
            symbols: [SlotSymbol(rows: ["WWW"])],
            labels: ["A"],
            theme: theme,
        )
        #expect(lines.count == SlotRenderer.lineCount(for: theme))
    }
}

struct SpinningFaceTests {
    private let pool = [
        SlotSymbol(rows: ["a"]),
        SlotSymbol(rows: ["b"]),
        SlotSymbol(rows: ["c"]),
    ]

    @Test(arguments: [
        (0, 0, "a"), // step 0, reel 0
        (1, 0, "b"), // step advances the face
        (2, 0, "c"),
        (3, 0, "a"), // wraps around the pool
        (0, 1, "a"), // reel 1 offset by index*3 == 3, wraps back to a
        (0, 2, "a"), // reel 2 offset by index*3 == 6, wraps back to a
        (1, 1, "b"), // (1 + 3) % 3 == 1
    ])
    func spinningFaceCyclesByStepAndIndex(step: Int, index: Int, expected: String) {
        let face = SlotRenderer.spinningFace(in: pool, step: step, index: index)
        #expect(face.rows == [expected])
    }

    @Test
    func adjacentReelsAreOffsetAtSameStep() {
        // index*3 with a 3-element pool means reels 0/1/2 all land on the same face only
        // because 3 % 3 == 0; a 2-element pool should stagger them.
        let twoPool = [SlotSymbol(rows: ["x"]), SlotSymbol(rows: ["y"])]
        let reel0 = SlotRenderer.spinningFace(in: twoPool, step: 0, index: 0)
        let reel1 = SlotRenderer.spinningFace(in: twoPool, step: 0, index: 1)
        #expect(reel0.rows == ["x"]) // (0 + 0) % 2
        #expect(reel1.rows == ["y"]) // (0 + 3) % 2 == 1
    }
}

struct CenteredEdgeCaseTests {
    @Test(arguments: [
        ("x", 5, "  x  "), // odd padding, left-biased
        ("xy", 5, " xy  "), // odd padding, extra space on the right
        ("xy", 4, " xy "), // even padding
        ("abc", 3, "abc"), // exact fit, untouched
        ("toolong", 3, "too"), // clipped to width
        ("", 3, "   "), // empty pads to all spaces
    ])
    func centeredPadsAndClips(text: String, width: Int, expected: String) {
        #expect(SlotRenderer.centered(text, width: width) == expected)
    }
}
