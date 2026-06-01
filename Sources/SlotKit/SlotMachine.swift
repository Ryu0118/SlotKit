import Foundation

/// An ASCII-art slot machine that dramatizes a set of parallel async checks.
///
/// Each ``SlotReel`` is a reel. While its check runs the reel spins through the
/// theme's symbols; when the check resolves the reel locks on the win or lose face.
/// When every reel wins, the theme's optional finale flourish fires.
///
/// Animation is TTY-only. When output is not interactive — pipes, CI, `NO_COLOR` —
/// nothing is drawn: the checks still run and a ``SlotResult`` is returned, so callers
/// can print their own plain lines and output stays deterministic.
public enum SlotMachine {
    /// How fast the rainbow gradient scrolls per spin frame (multiplies `step`).
    private static let phaseStep = 12
    /// How fast the gradient scrolls per finale frame — faster than `phaseStep` for flash.
    private static let finalePhaseStep = 36

    /// Spins `reels` concurrently and returns each reel's outcome.
    ///
    /// - Parameters:
    ///   - reels: the checks to run, one reel each.
    ///   - theme: visual + timing configuration (defaults to ``SlotTheme/default``).
    ///   - plain: force plain (`true`) or animated (`false`) output; `nil` auto-detects
    ///     the terminal. Pass `true` to honor a host `--silent`-style flag.
    /// - Returns: the per-reel outcomes; inspect ``SlotResult/allPassed``.
    @discardableResult
    public static func spin(
        _ reels: [SlotReel],
        theme: SlotTheme = .default,
        plain: Bool? = nil,
    ) async -> SlotResult {
        let animate = !(plain ?? !Terminal.isInteractive)
        guard animate, !reels.isEmpty else {
            return await runPlain(reels)
        }
        return await runAnimated(reels, theme: theme)
    }

    /// Spins reels declared as a ``SlotReelsBuilder`` block — the same as the array
    /// overload, but checks can be added conditionally (`if`) or in a loop (`for`).
    ///
    /// ```swift
    /// await SlotMachine.spin {
    ///     SlotReel(label: "BUILD") { compile() }
    ///     if isMainBranch { SlotReel(label: "DEPLOY") { try await deploy() } }
    /// }
    /// ```
    ///
    /// - Parameters:
    ///   - theme: visual + timing configuration (defaults to ``SlotTheme/default``).
    ///   - plain: force plain (`true`) or animated (`false`) output; `nil` auto-detects.
    ///   - reels: a builder block producing the checks to run.
    /// - Returns: the per-reel outcomes; inspect ``SlotResult/allPassed``.
    @discardableResult
    public static func spin(
        theme: SlotTheme = .default,
        plain: Bool? = nil,
        @SlotReelsBuilder _ reels: @Sendable () -> [SlotReel],
    ) async -> SlotResult {
        await spin(reels(), theme: theme, plain: plain)
    }

    private static func runPlain(_ reels: [SlotReel]) async -> SlotResult {
        var outcomes: [SlotOutcome] = []
        for reel in reels {
            let passed = await (try? reel.work()) ?? false
            outcomes.append(SlotOutcome(label: reel.label, passed: passed))
        }
        return SlotResult(outcomes: outcomes)
    }

    private static func spinReel(_ reel: SlotReel, index: Int, into results: ResultBox, minSpin: Double) async {
        let passed = await (try? reel.work()) ?? false
        try? await Task.sleep(for: .seconds(minSpin))
        await results.finish(index, passed: passed)
    }

    private static func runAnimated(_ reels: [SlotReel], theme: SlotTheme) async -> SlotResult {
        let results = ResultBox(count: reels.count)
        let labels = reels.map(\.label)

        // Run the per-reel checks as structured children alongside the draw loop, all
        // inside one task group so cancellation of the awaiting caller propagates to the
        // checks (and the draw loop sees `Task.isCancelled` and stops) instead of leaking
        // detached tasks that busy-spin stdout once their sleeps stop blocking.
        await withTaskGroup(of: Void.self) { group in
            for (index, reel) in reels.enumerated() {
                group.addTask { await spinReel(reel, index: index, into: results, minSpin: theme.minSpin) }
            }
            group.addTask {
                await drawLoop(results, labels: labels, theme: theme)
            }
            await group.waitForAll()
        }

        let outcomes = await results.outcomes(labels: labels)
        let result = SlotResult(outcomes: outcomes)
        if !Task.isCancelled {
            if result.allPassed, let finale = theme.finale {
                // Win: pulse the all-`win` grid bright ↔ dim (keeps its color).
                let winGrid = labels.map { _ in theme.win }
                await playFlash(finale, symbols: winGrid, style: .win, labels: labels, theme: theme)
            } else if !result.allPassed, let bust = theme.bust {
                // Bust: pulse the final grid red ↔ plain — no rainbow on a loss.
                let grid = outcomes.map { $0.passed ? theme.win : theme.lose }
                await playFlash(bust, symbols: grid, style: .bust, labels: labels, theme: theme)
            }
        }
        return result
    }

    private static func drawLoop(_ results: ResultBox, labels: [String], theme: SlotTheme) async {
        let lineCount = SlotRenderer.lineCount(for: theme)
        var step = 0
        var moveUp = 0
        while true {
            let frame = await results.frameState(step: step, theme: theme)
            await drawFrame(frame.symbols, labels: labels, theme: theme, step: step, moveUp: moveUp)
            moveUp = lineCount
            if frame.done || Task.isCancelled { return }
            step += 1
            do {
                try await Task.sleep(for: .seconds(theme.frameInterval))
            } catch {
                return // cancelled mid-sleep — stop rather than spin on instant-returning sleeps
            }
        }
    }

    /// How one grid frame paints its lines.
    enum GridStyle {
        /// The live look: run the theme's colorizer.
        case normal
        /// Uncolored: the raw line, colorizer bypassed (the bust flash's base beat — a loss
        /// shouldn't celebrate in rainbow between red pulses).
        case plain
        /// The win flash "off" beat: faint, colorizer bypassed.
        case dim
        /// The bust flash beat: bold pure-red (truecolor `#FF0000`), colorizer bypassed.
        case bust
    }

    /// The two beats a flash alternates between: `base` is the resting state shown on even
    /// frames AND the final settle frame; `pulse` is the momentary off-beat on odd frames.
    /// Win rests colored, blinks dim — `(.normal, .dim)`. Bust rests RED (so it starts and
    /// ends red), blinks to plain — `(.bust, .plain)`.
    struct FlashStyle {
        let base: GridStyle
        let pulse: GridStyle

        static let win = FlashStyle(base: .normal, pulse: .dim)
        static let bust = FlashStyle(base: .bust, pulse: .plain)
    }

    private static func drawFrame(
        _ symbols: [SlotSymbol],
        labels: [String],
        theme: SlotTheme,
        step: Int,
        moveUp: Int,
    ) async {
        let lines = SlotRenderer.frame(symbols: symbols, labels: labels, theme: theme)
        emit(gridFrame(lines, colorize: theme.colorize, phase: step * phaseStep, moveUp: moveUp, style: .normal))
    }

    /// Builds one grid frame string from already-rendered `lines`: an optional cursor-up by
    /// `moveUp` lines, then each line cleared. `.normal` colorizes at `phase`; `.dim` and
    /// `.bust` emit the line **without** the colorizer, wrapped in faint / bold pure-red SGR.
    /// Bypassing the colorizer is required because the built-in colorizers emit bold and
    /// truecolor foregrounds (`\u{1B}[1;38;2;…m`), which would otherwise override the faint
    /// or the red and defeat the flash. Pure — no I/O.
    static func gridFrame(
        _ lines: [String],
        colorize: SlotColorizer,
        phase: Int,
        moveUp: Int,
        style: GridStyle,
    ) -> String {
        var out = ""
        if moveUp > 0 { out += "\u{1B}[\(moveUp)A" }
        for line in lines {
            let painted: String = switch style {
            case .normal: colorize(line, phase)
            case .plain: line
            case .dim: "\u{1B}[2m\(line)\u{1B}[22m"
            case .bust: "\u{1B}[1;38;2;255;0;0m\(line)\u{1B}[0m"
            }
            out += "\r\(painted)\u{1B}[K\n"
        }
        return out
    }

    /// Flashes a grid that's already on screen in place — alternating `style.base` ↔
    /// `style.pulse` — then settles on the base frame so no pulse tint lingers under
    /// whatever the caller prints next. Used for both the win flash (`.win`, all `win`
    /// faces) and the bust flash (`.bust`, the real mixed grid).
    private static func playFlash(
        _ flash: SlotTheme.SlotFinale,
        symbols: [SlotSymbol],
        style: FlashStyle,
        labels: [String],
        theme: SlotTheme,
    ) async {
        let lines = SlotRenderer.frame(symbols: symbols, labels: labels, theme: theme)
        let lineCount = SlotRenderer.lineCount(for: theme)
        let frames = flashFrames(
            lines,
            colorize: theme.colorize,
            lineCount: lineCount,
            count: flash.frames,
            style: style,
        )
        for (index, frame) in frames.enumerated() {
            emit(frame)
            if index < frames.count - 1 { try? await Task.sleep(for: .seconds(flash.interval)) }
        }
    }

    /// The full sequence of flash frames: `count` beats alternating `base` (even) ↔ `pulse`
    /// (odd), plus a final `base` settle frame so the grid never ends on a pulse. Every
    /// frame moves up by `lineCount` to overwrite the grid already on screen. The win flash
    /// uses base `.normal` / pulse `.dim` (colored grid blinks faint); the bust flash uses
    /// base `.plain` / pulse `.bust` (uncolored grid pulses red — no rainbow on a loss).
    /// Pure — no I/O.
    static func flashFrames(
        _ lines: [String],
        colorize: SlotColorizer,
        lineCount: Int,
        count: Int,
        style: FlashStyle,
    ) -> [String] {
        (0 ... count).map { frame in
            let isPulse = frame < count && !frame.isMultiple(of: 2) // last frame settles on base
            let beat = isPulse ? style.pulse : style.base
            return gridFrame(lines, colorize: colorize, phase: frame * finalePhaseStep, moveUp: lineCount, style: beat)
        }
    }

    private static func emit(_ text: String) {
        FileHandle.standardOutput.write(Data(text.utf8))
    }

    /// Reel state shared between the animation loop and the per-check tasks.
    private actor ResultBox {
        private var finished: [Bool?]

        init(count: Int) {
            finished = Array(repeating: nil, count: count)
        }

        func finish(_ index: Int, passed: Bool) {
            finished[index] = passed
        }

        func outcomes(labels: [String]) -> [SlotOutcome] {
            labels.enumerated().map { index, label in
                SlotOutcome(label: label, passed: finished[index] == true)
            }
        }

        /// Whether every reel has resolved, plus each reel's current face — in one actor
        /// hop per frame regardless of reel count (resolved reels show win/lose, in-flight
        /// reels a spinning face cycled by `step`).
        func frameState(step: Int, theme: SlotTheme) -> (done: Bool, symbols: [SlotSymbol]) {
            let symbols = finished.indices.map { face(at: $0, step: step, theme: theme) }
            return (finished.allSatisfy { $0 != nil }, symbols)
        }

        private func face(at index: Int, step: Int, theme: SlotTheme) -> SlotSymbol {
            if let result = finished[index] {
                return result ? theme.win : theme.lose
            }
            return SlotRenderer.spinningFace(in: theme.spinning, step: step, index: index)
        }
    }
}
