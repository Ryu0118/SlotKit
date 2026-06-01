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

    private static func runPlain(_ reels: [SlotReel]) async -> SlotResult {
        var outcomes: [SlotOutcome] = []
        for reel in reels {
            let passed = await (try? reel.work()) ?? false
            outcomes.append(SlotOutcome(label: reel.label, passed: passed))
        }
        return SlotResult(outcomes: outcomes)
    }

    private static func runAnimated(_ reels: [SlotReel], theme: SlotTheme) async -> SlotResult {
        let results = ResultBox(count: reels.count)
        for (index, reel) in reels.enumerated() {
            Task { @Sendable in
                let passed = await (try? reel.work()) ?? false
                try? await Task.sleep(for: .seconds(theme.minSpin))
                await results.finish(index, passed: passed)
            }
        }

        let labels = reels.map(\.label)
        let lineCount = theme.cellHeight + 3
        var step = 0
        var firstDraw = true
        while await !results.allDone {
            await drawFrame(results, labels: labels, theme: theme, step: step, moveUp: firstDraw ? 0 : lineCount)
            firstDraw = false
            step += 1
            try? await Task.sleep(for: .seconds(theme.frameInterval))
        }
        await drawFrame(results, labels: labels, theme: theme, step: step, moveUp: firstDraw ? 0 : lineCount)

        let outcomes = await results.outcomes(labels: labels)
        let result = SlotResult(outcomes: outcomes)
        if result.allPassed, let finale = theme.finale {
            await playFinale(finale, colorize: theme.colorize)
        }
        return result
    }

    private static func drawFrame(
        _ results: ResultBox,
        labels: [String],
        theme: SlotTheme,
        step: Int,
        moveUp: Int,
    ) async {
        var symbols: [SlotSymbol] = []
        for index in labels.indices {
            await symbols.append(results.symbol(for: index, step: step, theme: theme))
        }
        var out = ""
        if moveUp > 0 { out += "\u{1B}[\(moveUp)A" }
        for line in SlotRenderer.frame(symbols: symbols, labels: labels, theme: theme) {
            out += "\r\(theme.colorize(line, step * 12))\u{1B}[K\n"
        }
        emit(out)
    }

    private static func playFinale(_ finale: SlotTheme.SlotFinale, colorize: SlotColorizer) async {
        for frame in 0 ..< finale.frames {
            let blink = frame.isMultiple(of: 2) ? "\u{1B}[5m" : ""
            emit("\r\(blink)\(colorize(finale.text, frame * 36))\u{1B}[K")
            try? await Task.sleep(for: .seconds(finale.interval))
        }
        emit("\r\u{1B}[K")
    }

    private static func emit(_ text: String) {
        guard let data = text.data(using: .utf8) else { return }
        FileHandle.standardOutput.write(data)
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

        var allDone: Bool {
            finished.allSatisfy { $0 != nil }
        }

        func outcomes(labels: [String]) -> [SlotOutcome] {
            labels.enumerated().map { index, label in
                SlotOutcome(label: label, passed: finished[index] == true)
            }
        }

        func symbol(for index: Int, step: Int, theme: SlotTheme) -> SlotSymbol {
            if let result = finished[index] {
                return result ? theme.win : theme.lose
            }
            let pool = theme.spinning
            return pool[(step + index * 3) % pool.count]
        }
    }
}
