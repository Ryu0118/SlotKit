@testable import SlotKit
import Testing

struct PaylineTests {
    @Test(arguments: [3, 4, 5])
    func allLinesForSquareIsRowsPlusTwoDiagonals(size: Int) {
        #expect(Payline.allLines(forSquare: size).count == size + 2)
    }

    @Test
    func rowCellsRunLeftToRightAcrossTheGivenRow() {
        let cells = Payline.row(1).cells(rows: 3, cols: 3)
        #expect(cells.map(\.row) == [1, 1, 1])
        #expect(cells.map(\.col) == [0, 1, 2])
    }

    @Test
    func mainDiagonalRunsTopLeftToBottomRight() {
        let cells = Payline.diagonal(.main).cells(rows: 3, cols: 3)
        #expect(cells.map { [$0.row, $0.col] } == [[0, 0], [1, 1], [2, 2]])
    }

    @Test
    func antiDiagonalRunsBottomLeftToTopRight() {
        let cells = Payline.diagonal(.anti).cells(rows: 3, cols: 3)
        #expect(cells.map { [$0.row, $0.col] } == [[2, 0], [1, 1], [0, 2]])
    }

    @Test
    func outOfRangeRowYieldsNoCells() {
        #expect(Payline.row(5).cells(rows: 3, cols: 3).isEmpty)
    }

    @Test
    func paylinesHaveStableIdentifiers() {
        #expect(Payline.row(2).id == "row-2")
        #expect(Payline.diagonal(.main).id == "diag-down")
        #expect(Payline.diagonal(.anti).id == "diag-up")
    }
}
