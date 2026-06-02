@testable import SlotKit
import Testing

struct GridEvaluationTests {
    private static let lines = Payline.allLines(forSquare: 3)

    private static func winningIDs(_ grid: [[Int]]) -> Set<String> {
        Set(GridEvaluation.winningLines(grid: grid, paylines: lines, rows: 3, cols: 3).map(\.id))
    }

    @Test
    func allSevensWinsEveryLine() {
        let grid = [[0, 0, 0], [0, 0, 0], [0, 0, 0]]
        #expect(Self.winningIDs(grid) == ["row-0", "row-1", "row-2", "diag-down", "diag-up"])
    }

    @Test
    func aSingleMatchingRowWinsOnlyThatRow() {
        let grid = [[1, 1, 1], [2, 0, 1], [0, 1, 2]]
        #expect(Self.winningIDs(grid) == ["row-0"])
    }

    @Test
    func mainDiagonalWins() {
        let grid = [[1, 2, 0], [0, 1, 2], [2, 0, 1]]
        #expect(Self.winningIDs(grid).contains("diag-down"))
    }

    @Test
    func antiDiagonalWins() {
        let grid = [[0, 2, 1], [2, 1, 0], [1, 0, 2]]
        #expect(Self.winningIDs(grid).contains("diag-up"))
    }

    @Test
    func aMixedGridWinsNothing() {
        // No row, and neither diagonal (↘ = 0,2,1 / ↗ = 1,2,0), all match.
        let grid = [[0, 1, 2], [0, 2, 1], [1, 0, 1]]
        #expect(Self.winningIDs(grid).isEmpty)
    }

    @Test
    func jackpotOnlyWhenAWinningLineIsTheJackpotSymbol() {
        let sevenRow = [[0, 0, 0], [1, 2, 1], [2, 1, 2]] // row-0 all 7 (index 0)
        let cherryRow = [[1, 1, 1], [0, 2, 0], [2, 0, 2]] // row-0 all cherry (index 1)
        #expect(GridEvaluation.isJackpot(grid: sevenRow, paylines: Self.lines, rows: 3, cols: 3, jackpotIndex: 0))
        #expect(!GridEvaluation.isJackpot(grid: cherryRow, paylines: Self.lines, rows: 3, cols: 3, jackpotIndex: 0))
    }

    @Test
    func noJackpotConfiguredIsNeverJackpot() {
        let grid = [[0, 0, 0], [0, 0, 0], [0, 0, 0]]
        #expect(!GridEvaluation.isJackpot(grid: grid, paylines: Self.lines, rows: 3, cols: 3, jackpotIndex: nil))
    }
}
