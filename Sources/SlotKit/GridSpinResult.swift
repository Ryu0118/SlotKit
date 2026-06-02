/// The result of a grid spin: where every cell landed and which paylines paid.
public struct GridSpinResult: Sendable, Equatable {
    /// The landed symbol index of every cell, indexed `landed[row][col]`.
    public let landed: [[Int]]
    /// The paylines that paid (every cell on the line shares one symbol).
    public let winningLines: [Payline]
    /// The jackpot symbol index this spin was judged against, or `nil` if the theme set none.
    public let jackpotIndex: Int?
    /// The per-column captions, in column order (`nil` for an unlabeled column).
    public let columnLabels: [String?]

    /// `true` when at least one payline paid.
    public var didWin: Bool {
        !winningLines.isEmpty
    }

    /// `true` when a winning line is a line of the jackpot symbol.
    public var isJackpot: Bool {
        guard let jackpotIndex else { return false }
        return winningLines.contains { line in
            guard let first = line.cells(rows: landed.count, cols: columnLabels.count).first else { return false }
            return landedIndex(row: first.row, col: first.col) == jackpotIndex
        }
    }

    /// The symbol index at a cell, or `0` if the coordinate is out of range.
    public func landedIndex(row: Int, col: Int) -> Int {
        guard landed.indices.contains(row), landed[row].indices.contains(col) else { return 0 }
        return landed[row][col]
    }

    /// Creates a grid result.
    public init(landed: [[Int]], winningLines: [Payline], jackpotIndex: Int?, columnLabels: [String?]) {
        self.landed = landed
        self.winningLines = winningLines
        self.jackpotIndex = jackpotIndex
        self.columnLabels = columnLabels
    }
}
