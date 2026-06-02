/// Scrolling (reel-strip) rendering for the grid path — an additive sibling of
/// ``GridRenderer/frame(grid:labels:theme:)``.
///
/// The non-scroll frame swaps each cell's whole symbol every step; a real slot reel instead
/// **scrolls** a vertical strip of faces past a fixed window, so a face slides in from the top
/// and is pushed out the bottom. This renderer draws that: a column is one reel whose cells
/// scroll together on a shared strip of ``SlotTheme/spinning`` faces, advancing one art row per
/// step (downward). Adjacent columns carry a phase offset so they don't move in lockstep.
///
/// It is **render-only and in-flight-only**: line count, layout, borders, and the landed frame
/// are identical to ``GridRenderer/frame(grid:labels:theme:)``.
///
/// **Single source of truth for the showing face.** Both this renderer and the skill-stop
/// (``GridResultBox/stopAtCurrentStep(_:theme:)``) compute "which `spinning` index is showing
/// in cell (column, row) at this `rowOffset`" through ``showingIndex(spinningCount:rowOffset:column:row:rows:)``.
/// That keeps the hand-stop WYSIWYG: a column lands on exactly the faces the player saw
/// scrolling, rounded to the nearest aligned frame.
extension GridRenderer {
    /// One scrolling frame's inputs. `spinning` is the shared pool every in-flight reel scrolls;
    /// `landed[col]`, when non-nil, is a settled column drawn statically (face indices into
    /// `spinning`'s symbols are resolved by the caller into `landedFaces`); `rowOffset` is how
    /// far the strip has scrolled in art rows (downward as it grows).
    struct ScrollInput {
        /// The faces an in-flight reel scrolls through (`theme.spinning`).
        var spinning: [SlotSymbol]
        /// Per-column settled faces; `nil` for a still-spinning column.
        var landedFaces: [[SlotSymbol]?]
        /// Scroll distance in art rows.
        var rowOffset: Int
        /// Grid height in cells.
        var rows: Int
        /// Per-column labels.
        var labels: [String?]
    }

    /// The fixed reel geometry shared by the renderer and the skill-stop: the grid's height in
    /// cells and a cell's height in art rows. Bundles the two so the showing-face math takes a
    /// single value instead of two loose ints.
    struct ScrollGeometry {
        /// Grid height in cells.
        var rows: Int
        /// A cell's height in art rows.
        var cellHeight: Int
    }

    /// The `spinning` index showing in cell `(column, row)` at scroll `rowOffset`, rounded to
    /// the aligned frame (so it is always a whole face, never a split). This is the one
    /// function the renderer and the skill-stop share — change it in one place and both the
    /// picture and the landing move together.
    ///
    /// A column is one reel: its `rows` cells are consecutive strip positions, so cell `row`
    /// shows the strip face `row` ahead of the top cell. The strip advances `rowOffset /
    /// cellHeight` whole faces. `column` adds a per-column phase so columns don't lockstep.
    static func showingIndex(
        spinningCount: Int,
        rowOffset: Int,
        column: Int,
        row: Int,
        geometry: ScrollGeometry,
    ) -> Int {
        let faceShift = rowOffset / geometry.cellHeight
        return wrap(faceShift + row + column * geometry.rows, count: spinningCount)
    }

    /// True modulo into `0 ..< count`.
    static func wrap(_ value: Int, count: Int) -> Int {
        ((value % count) + count) % count
    }

    /// Renders one scrolling frame. Layout matches ``frame(grid:labels:theme:)`` line-for-line.
    /// Returns plain lines (no ANSI).
    static func scrollingFrame(_ input: ScrollInput, theme: SlotTheme) -> [String] {
        let width = theme.cellWidth
        let cols = input.labels.count
        let top = border(left: "╔", fill: "═", right: "╗", width: width, count: cols)
        let rule = border(left: "╠", fill: "═", right: "╣", width: width, count: cols)
        let bottom = border(left: "╚", fill: "═", right: "╝", width: width, count: cols)

        var lines: [String] = [top]
        for row in 0 ..< input.rows {
            for artRow in 0 ..< theme.cellHeight {
                let windowRow = row * theme.cellHeight + artRow
                let cells = (0 ..< cols).map { col in
                    scrollCell(col: col, windowRow: windowRow, artRow: artRow, input: input, theme: theme)
                }
                lines.append(cells.map { "║" + SlotRenderer.centered($0, width: width) + "║" }.joined())
            }
            lines.append(row == input.rows - 1 ? bottom : rule)
        }
        guard hasLabels(input.labels) else { return lines }
        lines.append(input.labels.map { SlotRenderer.centered($0 ?? "", width: width + 2) }.joined())
        return lines
    }

    /// The art-row text at absolute strip position `position` (in art rows) for `column`,
    /// wrapping around the strip. The strip is `spinning` stacked vertically with a per-column
    /// phase of `column * rows` faces, so columns don't lockstep and the showing face matches
    /// ``showingIndex(spinningCount:rowOffset:column:row:rows:)`` at aligned offsets.
    static func stripArtRow(
        _ strip: [SlotSymbol],
        at position: Int,
        column: Int,
        rows: Int,
        cellHeight: Int,
    ) -> String {
        let phaseRows = column * rows * cellHeight
        let stripRows = strip.count * cellHeight
        let wrapped = wrap(position + phaseRows, count: stripRows)
        return strip[wrapped / cellHeight].rows[wrapped % cellHeight]
    }

    /// The art-row text for one cell. A settled column draws its landed face statically; an
    /// in-flight column reads the scrolling strip at `windowRow + rowOffset`, so the whole
    /// column moves as one reel and a face enters at the top as `rowOffset` grows (downward).
    private static func scrollCell(
        col: Int,
        windowRow: Int,
        artRow: Int,
        input: ScrollInput,
        theme: SlotTheme,
    ) -> String {
        if let settled = input.landedFaces[col] {
            let bandRow = windowRow / theme.cellHeight
            return settled[bandRow].rows[artRow]
        }
        return stripArtRow(
            input.spinning,
            at: windowRow + input.rowOffset,
            column: col,
            rows: input.rows,
            cellHeight: theme.cellHeight,
        )
    }
}
