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
        if result.allPassed, let finale = theme.finale, !Task.isCancelled {
            await playFinale(finale, colorize: theme.colorize)
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

    private static func drawFrame(
        _ symbols: [SlotSymbol],
        labels: [String],
        theme: SlotTheme,
        step: Int,
        moveUp: Int,
    ) async {
        var out = ""
        if moveUp > 0 { out += "\u{1B}[\(moveUp)A" }
        for line in SlotRenderer.frame(symbols: symbols, labels: labels, theme: theme) {
            out += "\r\(theme.colorize(line, step * phaseStep))\u{1B}[K\n"
        }
        emit(out)
    }

    private static func playFinale(_ finale: SlotTheme.SlotFinale, colorize: SlotColorizer) async {
        for frame in 0 ..< finale.frames {
            let blink = frame.isMultiple(of: 2) ? "\u{1B}[5m" : ""
            emit("\r\(blink)\(colorize(finale.text, frame * finalePhaseStep))\u{1B}[K")
            try? await Task.sleep(for: .seconds(finale.interval))
        }
        emit("\r\u{1B}[K")
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
