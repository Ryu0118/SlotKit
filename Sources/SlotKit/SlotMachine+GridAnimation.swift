import Foundation

/// The grid path's animation internals: the per-column draw loop, the finale flash (with
/// optional winning-row highlight), and the per-column result actor. Siblings of the
/// single-row versions in ``SlotMachine`` — they compute a 2D frame via ``GridRenderer`` and
/// funnel into the reusable ``SlotMachine/gridFrame(_:colorize:phase:moveUp:style:)`` and
/// ``SlotMachine/emit(_:)``, so the shared formatting stays single-sourced.
extension SlotMachine {
    /// The grid's draw loop: each frame asks `frameState` for the current `R × C` faces (and
    /// whether all columns have settled), draws them, then sleeps `frameInterval`. Mirrors
    /// ``runDrawLoop(labels:theme:frameState:)`` but for a 2D grid.
    static func runGridDrawLoop(
        labels: [String?],
        theme: SlotTheme,
        frameState: @Sendable (Int) async -> (done: Bool, grid: [[SlotSymbol]]),
    ) async {
        var step = 0
        var moveUp = 0
        while true {
            let frame = await frameState(step)
            let lineCount = GridRenderer.lineCount(
                rows: frame.grid.count,
                theme: theme,
                hasLabels: GridRenderer.hasLabels(labels),
            )
            await drawGridFrame(frame.grid, labels: labels, theme: theme, step: step, moveUp: moveUp)
            moveUp = lineCount
            if frame.done || Task.isCancelled { return }
            step += 1
            do {
                try await Task.sleep(for: .seconds(theme.frameInterval))
            } catch {
                return
            }
        }
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

    init(columns: Int, rows: Int) {
        landed = Array(repeating: nil, count: columns)
        self.rows = rows
    }

    func reveal(_ column: Int, indices: [Int]) {
        landed[column] = SlotMachine.fit(indices, to: rows)
    }

    func landedColumns() -> [[Int]] {
        landed.map { $0 ?? Array(repeating: 0, count: rows) }
    }

    /// Whether every column has settled, plus the current `R × C` faces — resolved columns
    /// show their landed symbols, in-flight columns spin every cell.
    func frameState(step: Int, theme: SlotTheme) -> (done: Bool, grid: [[SlotSymbol]]) {
        let columnFaces = landed.indices.map { column in faces(column: column, step: step, theme: theme) }
        let grid = (0 ..< rows).map { row in columnFaces.map { $0[row] } }
        return (landed.allSatisfy { $0 != nil }, grid)
    }

    private func faces(column: Int, step: Int, theme: SlotTheme) -> [SlotSymbol] {
        if let indices = landed[column] {
            return indices.map { SlotMachine.symbol(at: $0, theme: theme) }
        }
        return (0 ..< rows).map { row in
            SlotRenderer.spinningFace(in: theme.spinning, step: step, index: column * rows + row)
        }
    }
}
