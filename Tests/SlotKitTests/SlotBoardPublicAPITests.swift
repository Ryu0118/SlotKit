import SlotKit // not @testable — proves SlotBoard and the public spinningFace are reachable from outside the module
import Testing

struct SlotBoardPublicAPITests {
    @Test
    func slotBoardAndSpinningFaceArePublic() throws {
        let theme = try SlotTheme.make { draft in
            draft.cellWidth = 3
            draft.cellHeight = 1
            draft.win = SlotSymbol(rows: ["WWW"])
            draft.lose = SlotSymbol(rows: ["LLL"])
            draft.spinning = [SlotSymbol(rows: ["..."])]
        }
        // SlotBoard.spinningFace is public and selects from the pool.
        let face = SlotBoard.spinningFace(in: theme.spinning, step: 0, index: 0)
        #expect(face.rows == ["..."])
        // SlotBoard.frame is public and draws a board.
        let lines = SlotBoard.frame(symbols: [face], labels: ["A"], theme: theme, highlight: 0)
        #expect(!lines.isEmpty)
    }
}
