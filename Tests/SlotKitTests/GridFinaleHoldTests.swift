@testable import SlotKit
import Synchronization
import Testing

/// Verifies the held finale: with a `hold` closure, a winning grid keeps flashing until the
/// closure returns, and `playGridFinale` resolves only after the hold does — so the caller can
/// blink the win until the player presses on. With no hold the finale is its fixed length.
struct GridFinaleHoldTests {
    /// The held win finale resolves only after `hold` returns — the flash is gated on the
    /// keypress, not a fixed frame count.
    @Test
    func heldWinFinaleWaitsForHold() async throws {
        let theme = try Self.theme()
        let result = Self.winResult(theme: theme)
        let released = Mutex(false)
        // Hold for a few flash intervals, then release; the call must not return before that.
        await SlotMachine.playGridFinale(result, rows: 3, labels: [nil, nil, nil], theme: theme) {
            try? await Task.sleep(for: .milliseconds(20))
            released.withLock { $0 = true }
        }
        #expect(released.withLock { $0 }, "finale returned before hold released")
    }

    /// An immediately-returning hold ends the finale at once — no hang, the loop is cancelled.
    @Test
    func heldFinaleEndsWhenHoldReturnsImmediately() async throws {
        let theme = try Self.theme()
        let result = Self.winResult(theme: theme)
        await SlotMachine.playGridFinale(result, rows: 3, labels: [nil, nil, nil], theme: theme) {}
        // Reaching here at all proves the flash loop was cancelled rather than spinning forever.
        #expect(Bool(true))
    }

    /// With no hold the finale runs and returns on its own (the original behavior), no hang.
    @Test
    func unheldFinaleReturnsOnItsOwn() async throws {
        let theme = try Self.theme()
        let result = Self.winResult(theme: theme)
        await SlotMachine.playGridFinale(result, rows: 3, labels: [nil, nil, nil], theme: theme)
        #expect(Bool(true))
    }

    /// The held loss finale waits for the hold too — and because the bust flash and the hold
    /// run concurrently, the advance window is open during the flash (no dropped-press dead zone).
    @Test
    func heldLossFinaleWaitsForHold() async throws {
        let theme = try Self.theme()
        let result = Self.lossResult(theme: theme)
        #expect(!result.didWin)
        let released = Mutex(false)
        await SlotMachine.playGridFinale(result, rows: 3, labels: [nil, nil, nil], theme: theme) {
            try? await Task.sleep(for: .milliseconds(10))
            released.withLock { $0 = true }
        }
        #expect(released.withLock { $0 }, "loss finale returned before hold released")
    }

    private static func theme() throws -> SlotTheme {
        try Fixtures.symbolTheme() // symbols == spinning == [7, C, B], jackpotIndex 0, finale + bust set
    }

    /// A 3×3 all-jackpot (all index 0) win — every row pays, so the finale flashes.
    private static func winResult(theme: SlotTheme) -> GridSpinResult {
        let grid = Array(repeating: Array(repeating: 0, count: 3), count: 3)
        let lines = Payline.allLines(forSquare: 3)
        let winning = GridEvaluation.winningLines(grid: grid, paylines: lines, rows: 3, cols: 3)
        return GridSpinResult(
            landed: grid,
            winningLines: winning,
            jackpotIndex: theme.jackpotIndex,
            columnLabels: [nil, nil, nil],
        )
    }

    /// A 3×3 no-win board (no row or diagonal is all-equal), so the finale takes the loss path.
    private static func lossResult(theme: SlotTheme) -> GridSpinResult {
        // grid[col][row]. No row (same row index across cols), neither diagonal, is all-equal.
        let grid = [[0, 1, 2], [1, 2, 0], [0, 1, 2]]
        let lines = Payline.allLines(forSquare: 3)
        let winning = GridEvaluation.winningLines(grid: grid, paylines: lines, rows: 3, cols: 3)
        return GridSpinResult(
            landed: grid,
            winningLines: winning,
            jackpotIndex: theme.jackpotIndex,
            columnLabels: [nil, nil, nil],
        )
    }
}
