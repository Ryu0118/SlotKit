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
    ///
    /// When `hold` is given, a **win keeps flashing** until `hold` returns (e.g. a keypress);
    /// a loss holds its settled board until then. With `hold` nil the flash is the theme's
    /// fixed length and the board settles on its own — the original behavior.
    static func playGridFinale(
        _ result: GridSpinResult,
        rows: Int,
        labels: [String?],
        theme: SlotTheme,
        hold: (@Sendable () async -> Void)? = nil,
    ) async {
        let grid = result.landed.map { row in row.map { symbol(at: $0, theme: theme) } }
        let lines = GridRenderer.frame(grid: grid, labels: labels, theme: theme)
        if result.didWin, let finale = theme.finale {
            let mask = winningRowMask(result, rows: rows, theme: theme, hasLabels: GridRenderer.hasLabels(labels))
            let frames = gridFlashFrames(lines, theme: theme, count: finale.frames, style: .win, highlight: mask)
            await playWinFlash(frames, interval: finale.interval, hold: hold)
        } else if !result.didWin, let bust = theme.bust {
            let frames = gridFlashFrames(lines, theme: theme, count: bust.frames, style: .bust, highlight: nil)
            await playLossFlash(frames, interval: bust.interval, hold: hold)
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

    /// Emits each flash frame in turn, sleeping `interval` *between* frames (not after the last)
    /// — the single flash-playback loop shared by the grid and single-row finales.
    static func emitFlash(_ frames: [String], interval: Double) async {
        for (index, frame) in frames.enumerated() {
            emit(frame)
            if index < frames.count - 1 { try? await Task.sleep(for: .seconds(interval)) }
        }
    }

    /// Plays the loss flash. Without `hold` it runs once. With `hold`, the bust flash and the
    /// hold run concurrently — so the advance window is open *during* the flash, with no dead
    /// gap where a press is dropped — and the call returns only after both the flash finishes
    /// and the hold resolves.
    private static func playLossFlash(
        _ frames: [String],
        interval: Double,
        hold: (@Sendable () async -> Void)?,
    ) async {
        guard let hold else {
            await emitFlash(frames, interval: interval)
            return
        }
        await withTaskGroup(of: Void.self) { group in
            group.addTask { await emitFlash(frames, interval: interval) }
            group.addTask { await hold() }
            await group.waitForAll()
        }
    }

    /// Plays the win flash. Without `hold` it runs once (the original fixed-length flourish);
    /// with `hold` it loops the flash until `hold` returns, so the win blinks until the player
    /// presses on. The loop is cancelled the instant `hold` resolves.
    private static func playWinFlash(
        _ frames: [String],
        interval: Double,
        hold: (@Sendable () async -> Void)?,
    ) async {
        guard let hold else {
            await emitFlash(frames, interval: interval)
            return
        }
        await withTaskGroup(of: Void.self) { group in
            group.addTask { await loopFlash(frames, interval: interval) }
            group.addTask { await hold() }
            await group.next() // hold resolves (or the flash task ends); stop the other
            group.cancelAll()
        }
    }

    /// Replays `frames` forever, until the task is cancelled. The win-flash hold races this
    /// against the hold closure and cancels it when the closure returns. The trailing sleep
    /// paces the loop even when `frames` is a single frame (`emitFlash` sleeps only *between*
    /// frames, so a one-frame flash would otherwise spin the CPU and hammer stdout).
    private static func loopFlash(_ frames: [String], interval: Double) async {
        while !Task.isCancelled {
            await emitFlash(frames, interval: interval)
            do {
                try await Task.sleep(for: .seconds(interval))
            } catch {
                return
            }
        }
    }

    /// The gradient scroll step per grid spin frame (matches the single-row phase step).
    static var gridPhaseStep: Int {
        12
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
        // `.normal` here means "no flash" — the static masked frame shows the plain board.
        style.painted(line) ?? SlotColorizers.plain(line, 0)
    }
}
