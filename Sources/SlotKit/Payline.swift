/// A winning line on the grid: a set of cells that pays when they all show the same symbol.
///
/// A machine declares the lines it pays on — typically the horizontal rows plus the two
/// diagonals of a square grid (``allLines(forSquare:)``). The line's ``cells(rows:cols:)``
/// turns it into concrete `(row, col)` coordinates, which both the win evaluation and the
/// winning-line highlight read.
public struct Payline: Sendable, Equatable, Identifiable {
    /// The shape of a payline.
    public enum Kind: Sendable, Equatable {
        /// A horizontal row at the given index (top is `0`).
        case row(Int)
        /// The main diagonal, top-left to bottom-right (`↘`).
        case diagonalDown
        /// The anti-diagonal, bottom-left to top-right (`↗`).
        case diagonalUp
    }

    /// Which way to read a diagonal.
    public enum Diagonal: Sendable {
        /// Top-left to bottom-right (`↘`) — the main diagonal.
        case main
        /// Bottom-left to top-right (`↗`) — the anti-diagonal.
        case anti
    }

    /// The line's shape.
    public let kind: Kind
    /// A stable identifier (`"row-0"`, `"diag-down"`, `"diag-up"`) used to refer to a
    /// winning line — e.g. for highlighting or reporting.
    public let id: String

    /// Creates a horizontal payline at row `index` (top is `0`).
    public static func row(_ index: Int) -> Payline {
        Payline(kind: .row(index), id: "row-\(index)")
    }

    /// Creates a diagonal payline.
    public static func diagonal(_ diagonal: Diagonal) -> Payline {
        switch diagonal {
        case .main: Payline(kind: .diagonalDown, id: "diag-down")
        case .anti: Payline(kind: .diagonalUp, id: "diag-up")
        }
    }

    /// The standard paylines of a square `size × size` machine: every horizontal row plus
    /// the two diagonals — `size + 2` lines in all.
    public static func allLines(forSquare size: Int) -> [Payline] {
        (0 ..< size).map { Payline.row($0) } + [.diagonal(.main), .diagonal(.anti)]
    }

    /// The `(row, col)` cells this line covers on a `rows × cols` grid, left to right.
    /// Out-of-range rows (a `row(r)` with `r >= rows`) yield no cells. Diagonals are read
    /// across `min(rows, cols)` cells from their starting corner.
    public func cells(rows: Int, cols: Int) -> [(row: Int, col: Int)] {
        switch kind {
        case let .row(index):
            guard (0 ..< rows).contains(index) else { return [] }
            return (0 ..< cols).map { (row: index, col: $0) }
        case .diagonalDown:
            let count = min(rows, cols)
            return (0 ..< count).map { (row: $0, col: $0) }
        case .diagonalUp:
            let count = min(rows, cols)
            return (0 ..< count).map { (row: count - 1 - $0, col: $0) }
        }
    }
}
