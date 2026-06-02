/// Pure win evaluation for a grid spin: given the landed symbols and the machine's paylines,
/// which lines pay, and is any of them the jackpot.
///
/// Side-effect-free and total — this is the testable core of the grid result. `grid` is
/// indexed `grid[row][col]` and holds the landed symbol index of each cell.
public enum GridEvaluation {
    /// The paylines whose every cell shows the same symbol. A line covering no cells (an
    /// out-of-range row) never pays.
    public static func winningLines(
        grid: [[Int]],
        paylines: [Payline],
        rows: Int,
        cols: Int,
    ) -> [Payline] {
        paylines.filter { line in
            let cells = line.cells(rows: rows, cols: cols)
            guard let first = cells.first else { return false }
            let firstSymbol = symbol(at: first, in: grid)
            return cells.allSatisfy { symbol(at: $0, in: grid) == firstSymbol }
        }
    }

    /// Whether any winning line is a line of the jackpot symbol. `false` when no jackpot is
    /// configured or no line pays the jackpot symbol.
    public static func isJackpot(
        grid: [[Int]],
        paylines: [Payline],
        rows: Int,
        cols: Int,
        jackpotIndex: Int?,
    ) -> Bool {
        guard let jackpotIndex else { return false }
        return winningLines(grid: grid, paylines: paylines, rows: rows, cols: cols).contains { line in
            guard let first = line.cells(rows: rows, cols: cols).first else { return false }
            return symbol(at: first, in: grid) == jackpotIndex
        }
    }

    /// The symbol at a cell, or `-1` when the coordinate is outside the grid (so an
    /// out-of-range cell never accidentally matches a real symbol).
    private static func symbol(at cell: (row: Int, col: Int), in grid: [[Int]]) -> Int {
        guard grid.indices.contains(cell.row), grid[cell.row].indices.contains(cell.col) else {
            return -1
        }
        return grid[cell.row][cell.col]
    }
}
