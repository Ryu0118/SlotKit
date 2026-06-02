import Foundation

/// Skill-stop grid spins: each column keeps spinning until its ``SkillReel/stop`` signal
/// fires, then lands on the face showing at that frame — the player's reflex, not a
/// predetermined draw. A separate path from ``spinGrid(_:rows:paylines:theme:plain:)``, so
/// the predetermined-draw API stays unchanged.
public extension SlotMachine {
    /// Spins a grid where every column lands on whatever face it is showing the instant it is
    /// stopped (``SkillReel/stop``). The rarity of a face is set by the theme's
    /// ``SlotTheme/spinning`` pool — weight it to make a face hard to catch. Evaluates the
    /// landed grid against `paylines` just like ``spinGrid(_:rows:paylines:theme:plain:)``.
    ///
    /// - Parameters:
    ///   - columns: the columns to spin, one stop signal each.
    ///   - rows: the grid height.
    ///   - paylines: the lines a win is evaluated against.
    ///   - theme: visual + timing config; its ``SlotTheme/spinning`` faces are what scrolls by,
    ///     and its ``SlotTheme/symbols`` are the faces a stop can land on.
    ///   - plain: force plain (`true`) or animated (`false`); `nil` auto-detects the terminal.
    /// - Returns: where every column landed and which paylines paid.
    @discardableResult
    static func spinGridSkill(
        _ columns: [SkillReel],
        rows: Int,
        paylines: [Payline],
        theme: SlotTheme = .default,
        plain: Bool? = nil,
    ) async -> GridSpinResult {
        let animate = !(plain ?? !Terminal.isInteractive)
        guard animate, !columns.isEmpty, rows > 0 else {
            // Plain has no frames to skill-stop against — every column settles on index 0.
            let labels = columns.map(\.label)
            for column in columns {
                await column.stop()
            }
            let grid = (0 ..< rows).map { _ in Array(repeating: 0, count: columns.count) }
            return skillResult(grid: grid, labels: labels, rows: rows, paylines: paylines, theme: theme)
        }
        return await runAnimatedGridSkill(columns, rows: rows, paylines: paylines, theme: theme)
    }

    private static func runAnimatedGridSkill(
        _ columns: [SkillReel],
        rows: Int,
        paylines: [Payline],
        theme: SlotTheme,
    ) async -> GridSpinResult {
        let results = GridResultBox(columns: columns.count, rows: rows)
        let labels = columns.map(\.label)
        await withTaskGroup(of: Void.self) { group in
            for (index, column) in columns.enumerated() {
                group.addTask { await stopColumn(column, index: index, into: results, theme: theme) }
            }
            group.addTask {
                await runGridDrawLoop(labels: labels, theme: theme) { step in
                    await results.frameState(step: step, theme: theme)
                }
            }
            await group.waitForAll()
        }
        let grid = await Self.transpose(results.landedColumns(), rows: rows)
        let result = skillResult(grid: grid, labels: labels, rows: rows, paylines: paylines, theme: theme)
        if !Task.isCancelled {
            await playGridFinale(result, rows: rows, labels: labels, theme: theme)
        }
        return result
    }

    private static func stopColumn(
        _ column: SkillReel,
        index: Int,
        into results: GridResultBox,
        theme: SlotTheme,
    ) async {
        await column.stop()
        await results.stopAtCurrentStep(index, theme: theme)
    }

    private static func skillResult(
        grid: [[Int]],
        labels: [String?],
        rows: Int,
        paylines: [Payline],
        theme: SlotTheme,
    ) -> GridSpinResult {
        let winning = GridEvaluation.winningLines(grid: grid, paylines: paylines, rows: rows, cols: labels.count)
        return GridSpinResult(
            landed: grid,
            winningLines: winning,
            jackpotIndex: theme.jackpotIndex,
            columnLabels: labels,
        )
    }
}
