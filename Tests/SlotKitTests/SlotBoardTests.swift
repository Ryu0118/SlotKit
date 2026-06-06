@testable import SlotKit
import Testing

struct SlotBoardTests {
    private func makeTheme() throws -> SlotTheme {
        try SlotTheme.make { draft in
            draft.cellWidth = 3
            draft.cellHeight = 1
            draft.win = SlotSymbol(rows: ["WWW"])
            draft.lose = SlotSymbol(rows: ["LLL"])
            draft.spinning = [SlotSymbol(rows: ["..."])]
        }
    }

    private let reverseOn = "\u{1B}[7m"
    private let reverseOff = "\u{1B}[0m"

    @Test
    func nilHighlightIsIdenticalToSlotRenderer() throws {
        let theme = try makeTheme()
        let symbols = [SlotSymbol(rows: ["WWW"]), SlotSymbol(rows: ["LLL"])]
        let labels: [String?] = ["A", "B"]
        let board = SlotBoard.frame(symbols: symbols, labels: labels, theme: theme, highlight: nil)
        let plain = SlotRenderer.frame(symbols: symbols, labels: labels, theme: theme)
        #expect(board == plain)
    }

    @Test
    func highlightWrapsTheSelectedCellOnEveryLine() throws {
        let theme = try makeTheme()
        let symbols = [SlotSymbol(rows: ["WWW"]), SlotSymbol(rows: ["LLL"])]
        let lines = SlotBoard.frame(symbols: symbols, labels: ["A", "B"], theme: theme, highlight: 1)
        // cellWidth + 2 = 5 columns per cell; cell 1 spans columns 5..<10.
        // top: ╔═══╗[╔═══╗], art: ║WWW║[║LLL║], bottom: ╚═══╝[╚═══╝], label: "  A  "[ "  B  " ]
        #expect(lines[0] == "╔═══╗" + reverseOn + "╔═══╗" + reverseOff)
        #expect(lines[1] == "║WWW║" + reverseOn + "║LLL║" + reverseOff)
        #expect(lines[2] == "╚═══╝" + reverseOn + "╚═══╝" + reverseOff)
        // the label row is wrapped too.
        #expect(lines[3] == "  A  " + reverseOn + "  B  " + reverseOff)
    }

    @Test
    func highlightingTheFirstCellWrapsTheLeadingSpan() throws {
        let theme = try makeTheme()
        let symbols = [SlotSymbol(rows: ["WWW"]), SlotSymbol(rows: ["LLL"])]
        let lines = SlotBoard.frame(symbols: symbols, labels: ["A", "B"], theme: theme, highlight: 0)
        #expect(lines[1] == reverseOn + "║WWW║" + reverseOff + "║LLL║")
    }

    @Test
    func outOfRangeHighlightLeavesTheBoardPlain() throws {
        let theme = try makeTheme()
        let symbols = [SlotSymbol(rows: ["WWW"])]
        let lines = SlotBoard.frame(symbols: symbols, labels: ["A"], theme: theme, highlight: 5)
        #expect(!lines.contains { $0.contains(reverseOn) })
    }

    @Test
    func worksWithoutLabels() throws {
        let theme = try makeTheme()
        let symbols = [SlotSymbol(rows: ["WWW"]), SlotSymbol(rows: ["LLL"])]
        let lines = SlotBoard.frame(symbols: symbols, labels: [nil, nil], theme: theme, highlight: 1)
        // no label row (3 lines), and the highlight still wraps cell 1 on each.
        #expect(lines.count == 3)
        #expect(lines[1] == "║WWW║" + reverseOn + "║LLL║" + reverseOff)
    }
}
