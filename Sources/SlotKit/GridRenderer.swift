/// Pure, side-effect-free rendering of an `R × C` grid of cells.
///
/// Generalizes ``SlotRenderer`` from one row of boxed cells to a stack of `rows` row-bands.
/// Each band is a top/interior/bottom border plus `cellHeight` art rows; vertically-adjacent
/// bands share a `╠═══╣` rule instead of doubling borders. At `rows == 1` the output is
/// **byte-identical** to ``SlotRenderer/frame(symbols:labels:theme:)`` (top + art + bottom,
/// same separate-box glyphs), so the single-row paths keep their exact rendering.
enum GridRenderer {
    /// The number of lines ``frame(grid:labels:theme:)`` produces for a `rows`-tall grid:
    /// `rows × cellHeight` art lines, a top + bottom border, `rows - 1` interior rules, and —
    /// only when any column is labeled — one label row. This is the single source of truth
    /// the animation loop uses to reposition the cursor; keep it in lockstep with `frame`.
    static func lineCount(rows: Int, theme: SlotTheme, hasLabels: Bool) -> Int {
        rows * theme.cellHeight + (rows - 1) + 2 + (hasLabels ? 1 : 0)
    }

    /// Whether a label row is warranted: true if any column is labeled (mirrors
    /// ``SlotRenderer/hasLabels(_:)``).
    static func hasLabels(_ labels: [String?]) -> Bool {
        labels.contains { $0 != nil }
    }

    /// Renders the grid: a top border, then for each row-band its `cellHeight` art rows,
    /// with a `╠═══╣` rule between adjacent bands and a `╚═══╝` border at the bottom, and —
    /// only when any column is labeled — a label row. `grid` is indexed `grid[row][col]`.
    /// Returns plain lines (no ANSI).
    static func frame(grid: [[SlotSymbol]], labels: [String?], theme: SlotTheme) -> [String] {
        let width = theme.cellWidth
        let cols = labels.count
        let top = border(left: "╔", fill: "═", right: "╗", width: width, count: cols)
        let rule = border(left: "╠", fill: "═", right: "╣", width: width, count: cols)
        let bottom = border(left: "╚", fill: "═", right: "╝", width: width, count: cols)

        var lines: [String] = [top]
        for (rowIndex, rowSymbols) in grid.enumerated() {
            for artRow in 0 ..< theme.cellHeight {
                lines.append(artLine(rowSymbols, artRow: artRow, width: width))
            }
            lines.append(rowIndex == grid.count - 1 ? bottom : rule)
        }
        guard hasLabels(labels) else { return lines }
        lines.append(labels.map { SlotRenderer.centered($0 ?? "", width: width + 2) }.joined())
        return lines
    }

    private static func artLine(_ rowSymbols: [SlotSymbol], artRow: Int, width: Int) -> String {
        rowSymbols.map { "║" + SlotRenderer.centered($0.rows[artRow], width: width) + "║" }.joined()
    }

    private static func border(left: String, fill: String, right: String, width: Int, count: Int) -> String {
        String(repeating: left + String(repeating: fill, count: width) + right, count: count)
    }
}
