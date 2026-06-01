import Foundation

/// Symbol-matching spins: each reel lands on a face chosen from the theme's
/// ``SlotTheme/symbols``, and a win is "every reel landed on the same symbol" — a real
/// slot machine, rather than the per-reel pass/fail of ``SlotMachine/spin(_:theme:plain:)``.
public extension SlotMachine {
    /// Spins `reels` concurrently, each landing on a symbol it draws, and returns the line.
    ///
    /// A win is every reel showing the same symbol (``SymbolSpinResult/allSame``); the top
    /// line is every reel on the theme's ``SlotTheme/jackpotIndex`` (``SymbolSpinResult/isJackpot``).
    /// The theme must carry ``SlotTheme/symbols`` to land on; an empty set yields a result
    /// with every reel pinned to index 0 (nothing meaningful to draw).
    ///
    /// - Parameters:
    ///   - reels: the reels to spin, one draw each.
    ///   - theme: visual + timing configuration; its ``SlotTheme/symbols`` are the faces a
    ///     reel may land on (defaults to ``SlotTheme/default``, which carries none).
    ///   - plain: force plain (`true`) or animated (`false`) output; `nil` auto-detects the
    ///     terminal. Pass `true` to honor a host `--silent`-style flag.
    /// - Returns: the per-reel outcomes; inspect ``SymbolSpinResult/allSame`` / ``SymbolSpinResult/isJackpot``.
    @discardableResult
    static func spinSymbols(
        _ reels: [SymbolReel],
        theme: SlotTheme = .default,
        plain: Bool? = nil,
    ) async -> SymbolSpinResult {
        let animate = !(plain ?? !Terminal.isInteractive)
        guard animate, !reels.isEmpty else {
            return await runPlainSymbols(reels, theme: theme)
        }
        return await runAnimatedSymbols(reels, theme: theme)
    }

    /// The face a landed index maps to: the theme's symbol at that index, or a blank cell
    /// when the theme carries no symbols (a misconfigured symbol spin still renders aligned).
    static func symbol(at index: Int, theme: SlotTheme) -> SlotSymbol {
        guard theme.symbols.indices.contains(index) else {
            let blankRow = String(repeating: " ", count: theme.cellWidth)
            return SlotSymbol(rows: Array(repeating: blankRow, count: theme.cellHeight))
        }
        return theme.symbols[index]
    }

    private static func runPlainSymbols(_ reels: [SymbolReel], theme: SlotTheme) async -> SymbolSpinResult {
        var outcomes: [SymbolOutcome] = []
        for reel in reels {
            let landedIndex = await reel.landing()
            outcomes.append(SymbolOutcome(label: reel.label, landedIndex: landedIndex))
        }
        return SymbolSpinResult(outcomes: outcomes, jackpotIndex: theme.jackpotIndex)
    }

    private static func runAnimatedSymbols(_ reels: [SymbolReel], theme: SlotTheme) async -> SymbolSpinResult {
        let results = SymbolResultBox(count: reels.count)
        let labels = reels.map(\.label)

        // Mirror of `runAnimated`'s structured task group, kept deliberately separate from
        // the Bool path: the per-reel work resolves to a symbol index, not a pass/fail.
        await withTaskGroup(of: Void.self) { group in
            for (index, reel) in reels.enumerated() {
                group.addTask { await landReel(reel, index: index, into: results, minSpin: theme.minSpin) }
            }
            group.addTask {
                await runDrawLoop(labels: labels, theme: theme) { step in
                    await results.frameState(step: step, theme: theme)
                }
            }
            await group.waitForAll()
        }

        let outcomes = await results.outcomes(labels: labels)
        let result = SymbolSpinResult(outcomes: outcomes, jackpotIndex: theme.jackpotIndex)
        if !Task.isCancelled {
            await playSymbolFinale(result, outcomes: outcomes, labels: labels, theme: theme)
        }
        return result
    }

    /// Plays the closing flash for a symbol spin: a winning line (all reels same) flashes
    /// the settled grid like the Bool win; any other line gets the restrained bust sink.
    private static func playSymbolFinale(
        _ result: SymbolSpinResult,
        outcomes: [SymbolOutcome],
        labels: [String?],
        theme: SlotTheme,
    ) async {
        let grid = outcomes.map { symbol(at: $0.landedIndex, theme: theme) }
        if result.allSame, let finale = theme.finale {
            await playFlash(finale, symbols: grid, style: .win, labels: labels, theme: theme)
        } else if !result.allSame, let bust = theme.bust {
            await playFlash(bust, symbols: grid, style: .bust, labels: labels, theme: theme)
        }
    }

    private static func landReel(_ reel: SymbolReel, index: Int, into results: SymbolResultBox, minSpin: Double) async {
        let landedIndex = await reel.landing()
        try? await Task.sleep(for: .seconds(minSpin))
        await results.finish(index, landedIndex: landedIndex)
    }
}

/// Reel state for the symbol path: each reel resolves to a landed symbol index. Mirrors the
/// Bool path's `ResultBox` but stores an index, not a pass/fail — kept separate by design.
private actor SymbolResultBox {
    private var landed: [Int?]

    init(count: Int) {
        landed = Array(repeating: nil, count: count)
    }

    func finish(_ index: Int, landedIndex: Int) {
        landed[index] = landedIndex
    }

    func outcomes(labels: [String?]) -> [SymbolOutcome] {
        labels.enumerated().map { index, label in
            SymbolOutcome(label: label, landedIndex: landed[index] ?? 0)
        }
    }

    /// Whether every reel has settled, plus each reel's current face — resolved reels show
    /// their landed symbol, in-flight reels a spinning face cycled by `step`.
    func frameState(step: Int, theme: SlotTheme) -> (done: Bool, symbols: [SlotSymbol]) {
        let symbols = landed.indices.map { face(at: $0, step: step, theme: theme) }
        return (landed.allSatisfy { $0 != nil }, symbols)
    }

    private func face(at index: Int, step: Int, theme: SlotTheme) -> SlotSymbol {
        if let landedIndex = landed[index] {
            return SlotMachine.symbol(at: landedIndex, theme: theme)
        }
        return SlotRenderer.spinningFace(in: theme.spinning, step: step, index: index)
    }
}
