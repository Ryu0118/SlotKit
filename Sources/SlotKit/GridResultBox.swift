/// Per-column reel state for the grid path: a column reveals all its cells at once when its
/// draw resolves. Mirrors ``SlotMachine``'s single-row result actors, keyed per column.
actor GridResultBox {
    private var landed: [[Int]?]
    private let rows: Int
    /// The most recent frame `step` the draw loop drew — so a skill-stop can land a column on
    /// whatever face is showing *right now* without the caller having to know the frame count.
    private var lastStep = 0

    init(columns: Int, rows: Int) {
        landed = Array(repeating: nil, count: columns)
        self.rows = rows
    }

    func reveal(_ column: Int, indices: [Int]) {
        landed[column] = SlotMachine.fit(indices, to: rows)
    }

    /// Stops `column` on the face it is showing at the latest drawn step — the skill-stop. For
    /// each cell, the spinning face showing at `lastStep` is mapped back to a ``SlotTheme/symbols``
    /// index (so a weighted `spinning` pool makes the landed symbol as rare as the pool makes
    /// it). A spinning face not in `symbols` lands as index 0.
    ///
    /// The "showing face" must match what the player saw, so it is read through the SAME
    /// function the renderer draws with: ``SlotRenderer/spinningFace(in:step:index:)`` for the
    /// frame-swap look, or ``GridRenderer/showingIndex(spinningCount:rowOffset:column:row:geometry:)``
    /// (the scroll position at `lastStep`, rounded to the aligned face) when scrolling.
    func stopAtCurrentStep(_ column: Int, theme: SlotTheme) {
        let indices = (0 ..< rows).map { row in
            let face = showingFace(column: column, row: row, step: lastStep, theme: theme)
            return theme.symbols.firstIndex(of: face) ?? 0
        }
        landed[column] = indices
    }

    func landedColumns() -> [[Int]] {
        landed.map { $0 ?? Array(repeating: 0, count: rows) }
    }

    /// Whether every column has settled, plus the current `R × C` faces — resolved columns
    /// show their landed symbols, in-flight columns spin every cell.
    func frameState(step: Int, theme: SlotTheme) -> (done: Bool, grid: [[SlotSymbol]]) {
        lastStep = step
        let columnFaces = landed.indices.map { column in faces(column: column, step: step, theme: theme) }
        let grid = (0 ..< rows).map { row in columnFaces.map { $0[row] } }
        return (isDone, grid)
    }

    /// The scrolling-frame inputs at `step`: the shared spinning pool, each column's landed
    /// faces (`nil` while in flight), and the scroll offset (`rowOffset == step`, one art row
    /// per frame). Records `lastStep` like ``frameState(step:theme:)`` so a skill-stop lands on
    /// the showing face. The draw loop uses this only when ``SlotTheme/scrollSpin`` is on.
    func scrollState(
        step: Int,
        theme: SlotTheme,
        labels: [String?],
    ) -> (done: Bool, input: GridRenderer.ScrollInput) {
        lastStep = step
        let landedFaces = landed.map { column in
            column.map { indices in indices.map { SlotMachine.symbol(at: $0, theme: theme) } }
        }
        let input = GridRenderer.ScrollInput(
            spinning: theme.spinning,
            landedFaces: landedFaces,
            rowOffset: step,
            rows: rows,
            labels: labels,
        )
        return (isDone, input)
    }

    /// Whether every column has settled (its draw resolved). Both frame-state queries report it.
    private var isDone: Bool {
        landed.allSatisfy { $0 != nil }
    }

    private func faces(column: Int, step: Int, theme: SlotTheme) -> [SlotSymbol] {
        if let indices = landed[column] {
            return indices.map { SlotMachine.symbol(at: $0, theme: theme) }
        }
        return (0 ..< rows).map { row in showingFace(column: column, row: row, step: step, theme: theme) }
    }

    /// The aligned face an in-flight cell `(column, row)` shows at `step` — the single source of
    /// truth shared by the draw loop (via `faces`) and the skill-stop (`stopAtCurrentStep`), so
    /// a hand stop always lands on the face the player saw. Reads `column`'s strip
    /// (``SlotTheme/strip(forColumn:)``) so per-reel weighting lands as it scrolls. Scrolling
    /// reads the strip position at `step`; the frame-swap look reads
    /// ``SlotRenderer/spinningFace(in:step:index:)``.
    private func showingFace(column: Int, row: Int, step: Int, theme: SlotTheme) -> SlotSymbol {
        let strip = theme.strip(forColumn: column)
        guard theme.scrollSpin else {
            return SlotRenderer.spinningFace(in: strip, step: step, index: column * rows + row)
        }
        let index = GridRenderer.showingIndex(
            spinningCount: strip.count,
            rowOffset: step,
            column: column,
            row: row,
            geometry: GridRenderer.ScrollGeometry(rows: rows, cellHeight: theme.cellHeight),
        )
        return strip[index]
    }
}
