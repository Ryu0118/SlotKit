import Foundation

/// The grid path's animation internals: the per-column draw loop, the finale flash (with
/// optional winning-row highlight), and the per-column result actor. Siblings of the
/// single-row versions in ``SlotMachine`` — they compute a 2D frame via ``GridRenderer`` and
/// funnel into the reusable ``SlotMachine/gridFrame(_:colorize:phase:moveUp:style:)`` and
/// ``SlotMachine/emit(_:)``, so the shared formatting stays single-sourced.
extension SlotMachine {
    /// The grid's draw loop: each frame asks `results` for the current `R × C` faces (and
    /// whether all columns have settled), draws them, then sleeps `frameInterval`. Mirrors
    /// ``runDrawLoop(labels:theme:frameState:)`` but for a 2D grid. When ``SlotTheme/scrollSpin``
    /// is on, in-flight reels scroll their strips (one art row per frame) via
    /// ``GridRenderer/scrollingFrame(_:theme:)``; otherwise faces swap whole each frame.
    static func runGridDrawLoop(
        labels: [String?],
        theme: SlotTheme,
        results: GridResultBox,
        rows: Int,
    ) async {
        let context = GridDrawContext(labels: labels, theme: theme, results: results, rows: rows)
        var step = 0
        var moveUp = 0
        let lineCount = GridRenderer.lineCount(rows: rows, theme: theme, hasLabels: GridRenderer.hasLabels(labels))
        while true {
            let done = await drawOneGridFrame(context, step: step, moveUp: moveUp)
            moveUp = lineCount
            if done || Task.isCancelled { return }
            step += 1
            do {
                try await Task.sleep(for: .seconds(theme.frameInterval))
            } catch {
                return
            }
        }
    }

    /// The loop-invariant inputs of the grid draw loop, bundled so the per-frame draw takes one
    /// value beside the changing `step` / `moveUp`.
    struct GridDrawContext {
        var labels: [String?]
        var theme: SlotTheme
        var results: GridResultBox
        var rows: Int
    }

    static func drawGridFrame(
        _ grid: [[SlotSymbol]],
        labels: [String?],
        theme: SlotTheme,
        step: Int,
        moveUp: Int,
    ) async {
        let lines = GridRenderer.frame(grid: grid, labels: labels, theme: theme)
        emit(gridFrame(lines, colorize: theme.colorize, phase: step * gridPhaseStep, moveUp: moveUp, style: .normal))
    }

    /// Plays the closing flash for a grid spin. A win flashes the grid (highlighting the
    /// winning rows when any row paid); a loss does the restrained bust sink. Diagonal-only
    /// wins fall back to a whole-grid win flash (row-level SGR can't light a diagonal).
    static func playGridFinale(
        _ result: GridSpinResult,
        rows: Int,
        labels: [String?],
        theme: SlotTheme,
    ) async {
        let grid = result.landed.map { row in row.map { symbol(at: $0, theme: theme) } }
        let lines = GridRenderer.frame(grid: grid, labels: labels, theme: theme)
        if result.didWin, let finale = theme.finale {
            let mask = winningRowMask(result, rows: rows, theme: theme, hasLabels: GridRenderer.hasLabels(labels))
            let frames = gridFlashFrames(lines, theme: theme, count: finale.frames, style: .win, highlight: mask)
            await emitFlash(frames, interval: finale.interval)
        } else if !result.didWin, let bust = theme.bust {
            let frames = gridFlashFrames(lines, theme: theme, count: bust.frames, style: .bust, highlight: nil)
            await emitFlash(frames, interval: bust.interval)
        }
    }

    /// The flash frames for a grid: like ``flashFrames(_:colorize:lineCount:count:style:)``,
    /// but when `highlight` is given, only the marked **output lines** pulse — the rest stay
    /// on the base look — so a winning row blinks while the rest of the grid holds.
    static func gridFlashFrames(
        _ lines: [String],
        theme: SlotTheme,
        count: Int,
        style: FlashStyle,
        highlight: [Bool]?,
    ) -> [String] {
        let lineCount = lines.count
        guard let highlight else {
            return flashFrames(lines, colorize: theme.colorize, lineCount: lineCount, count: count, style: style)
        }
        return (0 ... count).map { frame in
            let isPulse = frame < count && !frame.isMultiple(of: 2)
            return maskedFrame(lines, highlight: highlight, pulsing: isPulse, style: style, moveUp: lineCount)
        }
    }

    /// A per-output-line mask marking the art lines of the winning rows, so the finale can
    /// blink just those. `nil` when no full row paid (only diagonals) — caller flashes whole.
    static func winningRowMask(
        _ result: GridSpinResult,
        rows: Int,
        theme: SlotTheme,
        hasLabels: Bool,
    ) -> [Bool]? {
        let winningRows = result.winningLines.compactMap { line -> Int? in
            if case let .row(index) = line.kind { return index }
            return nil
        }
        guard !winningRows.isEmpty else { return nil }
        let total = GridRenderer.lineCount(rows: rows, theme: theme, hasLabels: hasLabels)
        var mask = Array(repeating: false, count: total)
        for row in winningRows {
            // Layout: line 0 is the top border; each band is cellHeight art lines then a
            // border/rule line. Band `row` art starts at 1 + row*(cellHeight+1).
            let artStart = 1 + row * (theme.cellHeight + 1)
            for offset in 0 ..< theme.cellHeight where artStart + offset < total {
                mask[artStart + offset] = true
            }
        }
        return mask
    }

    /// Draws one grid frame (scroll or frame-swap, per ``SlotTheme/scrollSpin``) and reports
    /// whether every column has settled. Split out so the loop body stays flat.
    private static func drawOneGridFrame(_ context: GridDrawContext, step: Int, moveUp: Int) async -> Bool {
        let theme = context.theme
        if theme.scrollSpin {
            let frame = await context.results.scrollState(step: step, theme: theme, labels: context.labels)
            let lines = GridRenderer.scrollingFrame(frame.input, theme: theme)
            emit(gridFrame(
                lines,
                colorize: theme.colorize,
                phase: step * gridPhaseStep,
                moveUp: moveUp,
                style: .normal,
            ))
            return frame.done
        }
        let frame = await context.results.frameState(step: step, theme: theme)
        await drawGridFrame(frame.grid, labels: context.labels, theme: theme, step: step, moveUp: moveUp)
        return frame.done
    }

    /// The gradient scroll step per grid spin frame (matches the single-row phase step).
    static var gridPhaseStep: Int {
        12
    }

    private static func emitFlash(_ frames: [String], interval: Double) async {
        for (index, frame) in frames.enumerated() {
            emit(frame)
            if index < frames.count - 1 { try? await Task.sleep(for: .seconds(interval)) }
        }
    }

    private static func maskedFrame(
        _ lines: [String],
        highlight: [Bool],
        pulsing: Bool,
        style: FlashStyle,
        moveUp: Int,
    ) -> String {
        var out = "\u{1B}[\(moveUp)A"
        for (index, line) in lines.enumerated() {
            let lit = index < highlight.count && highlight[index]
            let beat: GridStyle = (lit && pulsing) ? style.pulse : style.base
            let painted = paint(line, style: beat)
            out += "\r\(painted)\u{1B}[K\n"
        }
        return out
    }

    private static func paint(_ line: String, style: GridStyle) -> String {
        switch style {
        case .normal: SlotColorizers.plain(line, 0)
        case .dim: "\u{1B}[2m\(line)\u{1B}[22m"
        case .bust: "\u{1B}[1;38;2;255;0;0m\(line)\u{1B}[0m"
        case .orange: "\u{1B}[1;38;2;255;85;0m\(line)\u{1B}[0m"
        }
    }
}

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
        let indices = (0 ..< rows).map { row -> Int in
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
        return (landed.allSatisfy { $0 != nil }, grid)
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
        return (landed.allSatisfy { $0 != nil }, input)
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
