@testable import SlotKit
import Testing

struct SlotMachineTests {
    @Test
    func plainSpinRunsChecksAndReportsOutcomes() async {
        let reels = [
            SlotReel(label: "A") { true },
            SlotReel(label: "B") { false },
            SlotReel(label: "C") { throw CancellationError() },
        ]
        let result = await SlotMachine.spin(reels, plain: true)
        #expect(result.outcomes == [
            SlotOutcome(label: "A", passed: true),
            SlotOutcome(label: "B", passed: false),
            SlotOutcome(label: "C", passed: false),
        ])
        #expect(!result.allPassed)
    }

    @Test
    func allPassedWhenEveryReelWins() async {
        let reels = [
            SlotReel(label: "A") { true },
            SlotReel(label: "B") { true },
        ]
        let result = await SlotMachine.spin(reels, plain: true)
        #expect(result.allPassed)
    }

    @Test
    func emptyReelsReturnEmptyResult() async {
        let result = await SlotMachine.spin([], plain: true)
        #expect(result.outcomes.isEmpty)
        #expect(result.allPassed) // vacuously true
    }

    @Test
    func cancellationPropagatesToReelsOnAnimatedPath() async {
        // Regression for the busy-spin / leaked-task bug: the animated path (`plain: false`)
        // must propagate cancellation into the reel checks and return promptly, not spin.
        let observedCancellation = ObservedFlag()
        let reels = [
            SlotReel(label: "SLOW") {
                do {
                    try await Task.sleep(for: .seconds(60))
                } catch {
                    await observedCancellation.set()
                    throw error
                }
                return true
            },
        ]

        let task = Task { await SlotMachine.spin(reels, plain: false) }
        // Let the spin start, then cancel and confirm it unwinds quickly.
        try? await Task.sleep(for: .milliseconds(50))
        task.cancel()
        _ = await task.value

        #expect(await observedCancellation.value) // cancellation reached the reel's work()
    }

    private actor ObservedFlag {
        private(set) var value = false
        func set() {
            value = true
        }
    }
}

struct SlotMachineAnimatedTests {
    @Test
    func animatedAllWinReportsEveryReelPassed() async throws {
        let theme = try Fixtures.fastTheme()
        let reels = [
            SlotReel(label: "A") { true },
            SlotReel(label: "B") { true },
            SlotReel(label: "C") { true },
        ]
        let result = await SlotMachine.spin(reels, theme: theme, plain: false)
        #expect(result.allPassed)
        #expect(result.outcomes.map(\.label) == ["A", "B", "C"])
    }

    @Test
    func animatedPartialFailReportsPerReelOutcomes() async throws {
        let theme = try Fixtures.fastTheme()
        let reels = [
            SlotReel(label: "A") { true },
            SlotReel(label: "B") { false },
            SlotReel(label: "C") { true },
        ]
        let result = await SlotMachine.spin(reels, theme: theme, plain: false)
        #expect(!result.allPassed)
        #expect(result.outcomes == [
            SlotOutcome(label: "A", passed: true),
            SlotOutcome(label: "B", passed: false),
            SlotOutcome(label: "C", passed: true),
        ])
    }

    @Test
    func animatedThrowingReelCountsAsFailure() async throws {
        let theme = try Fixtures.fastTheme()
        let reels = [
            SlotReel(label: "OK") { true },
            SlotReel(label: "ERR") { throw CancellationError() },
        ]
        let result = await SlotMachine.spin(reels, theme: theme, plain: false)
        #expect(result.outcomes == [
            SlotOutcome(label: "OK", passed: true),
            SlotOutcome(label: "ERR", passed: false),
        ])
        #expect(!result.allPassed)
    }

    @Test
    func animatedPathPreservesReelOrder() async throws {
        // Reels resolve at staggered times; the result must stay in input order.
        let theme = try Fixtures.fastTheme()
        let reels = [
            SlotReel(label: "SLOW") {
                try? await Task.sleep(for: .milliseconds(30))
                return true
            },
            SlotReel(label: "FAST") { true },
        ]
        let result = await SlotMachine.spin(reels, theme: theme, plain: false)
        #expect(result.outcomes.map(\.label) == ["SLOW", "FAST"])
    }
}

struct GridFrameTests {
    private let grid = ["AAA", "BBB", "CCC"] // a 3-line grid

    @Test
    func movesCursorUpByMoveUp() {
        // The all-win flash redraws the grid that's already on screen above the cursor, so
        // every flash frame must move up by the grid height to overwrite it in place.
        let out = SlotMachine.gridFrame(grid, colorize: SlotColorizers.plain, phase: 0, moveUp: 3, style: .normal)
        #expect(out.contains("\u{1B}[3A"))
    }

    @Test
    func noMoveUpWhenMoveUpIsZero() {
        // The very first grid draw (spin start) has nothing above it yet — no cursor-up.
        let out = SlotMachine.gridFrame(grid, colorize: SlotColorizers.plain, phase: 0, moveUp: 0, style: .normal)
        #expect(!out.hasPrefix("\u{1B}[")) // doesn't open with a reposition escape
        #expect(!out.contains("\u{1B}[3A"))
    }

    @Test
    func dimFrameIsFaintAndBypassesTheBoldColorizer() {
        // `rainbow` emits bold (`\u{1B}[1;...`). The dim frame must NOT run the colorizer,
        // because a leading bold would override the faint and defeat the flash — so the
        // dim frame carries faint and no bold; the bright frame is the reverse.
        let dim = SlotMachine.gridFrame(grid, colorize: SlotColorizers.rainbow, phase: 0, moveUp: 3, style: .dim)
        #expect(dim.contains("\u{1B}[2m")) // faint applied
        #expect(!dim.contains("\u{1B}[1;")) // colorizer's bold absent
        #expect(dim.contains("AAA")) // grid still drawn

        let bright = SlotMachine.gridFrame(grid, colorize: SlotColorizers.rainbow, phase: 0, moveUp: 3, style: .normal)
        #expect(bright.contains("\u{1B}[1;")) // colorized (bold) as usual
        #expect(!bright.contains("\u{1B}[2m")) // not faint
    }

    @Test
    func bustFrameIsRedAndBypassesTheColorizer() {
        // The bust beat must beat the colorizer and be pure red (`#FF0000`), not the
        // colorizer's scrolling rainbow — so it bypasses the colorizer entirely.
        let bust = SlotMachine.gridFrame(grid, colorize: SlotColorizers.rainbow, phase: 0, moveUp: 3, style: .bust)
        #expect(bust.contains("\u{1B}[1;38;2;255;0;0m")) // bold pure red applied
        #expect(!bust.contains("\u{1B}[1;38;2;255;59;0m")) // not a rainbow hue (the colorizer's output)
        #expect(bust.contains("AAA")) // grid still drawn
    }

    @Test
    func everyGridLineIsPresentAndClosed() {
        let out = SlotMachine.gridFrame(grid, colorize: SlotColorizers.plain, phase: 0, moveUp: 3, style: .normal)
        #expect(out.contains("AAA"))
        #expect(out.contains("BBB"))
        #expect(out.contains("CCC"))
        // One newline per line, and each line cleared to end-of-line.
        #expect(out.count { $0 == "\n" } == grid.count)
        #expect(out.contains("\u{1B}[K"))
    }
}

struct FinaleFramesTests {
    private let grid = ["AAA", "BBB"]

    @Test
    func endsOnABrightSettleFrame() throws {
        // count blink frames + one settle frame; the grid must never be left dimmed.
        let frames = SlotMachine.flashFrames(
            grid, colorize: SlotColorizers.rainbow, lineCount: 2, count: 6, style: .win,
        )
        #expect(frames.count == 7) // count + settle
        #expect(try !#require(frames.last?.contains("\u{1B}[2m"))) // last frame is bright, not faint
        #expect(try #require(frames.last?.contains("\u{1B}[1;"))) // and colorized
    }

    @Test
    func everyFrameRepositionsOntoTheGrid() {
        // Each flash frame overwrites the on-screen grid, so all move up by lineCount.
        let frames = SlotMachine.flashFrames(
            grid, colorize: SlotColorizers.rainbow, lineCount: 2, count: 4, style: .win,
        )
        #expect(frames.allSatisfy { $0.contains("\u{1B}[2A") })
    }

    @Test
    func blinkTogglesAcrossFrames() {
        // At least one dim frame exists between bright frames (the actual チカチカ).
        let frames = SlotMachine.flashFrames(
            grid, colorize: SlotColorizers.rainbow, lineCount: 2, count: 4, style: .win,
        )
        let dimFrames = frames.filter { $0.contains("\u{1B}[2m") }
        #expect(!dimFrames.isEmpty)
        #expect(dimFrames.count < frames.count) // and bright frames too
    }

    @Test
    func bustSequenceNeverShowsTheColorizerAndPulsesRed() throws {
        // The bug: bust used to alternate normal(rainbow) ↔ red, so a loss still flashed
        // rainbow. The whole sequence must stay off the colorizer — pure red ↔ plain. The
        // bust red is `255;0;0`; the rainbow's non-red hues (e.g. `255;59;0` at offset 1)
        // must never appear, which is what distinguishes a bust frame from a rainbow frame.
        let frames = SlotMachine.flashFrames(
            grid, colorize: SlotColorizers.rainbow, lineCount: 2, count: 4, style: .bust,
        )
        #expect(frames.allSatisfy { !$0.contains("\u{1B}[1;38;2;255;59;0m") }) // no rainbow hue anywhere
        #expect(frames.contains { $0.contains("\u{1B}[1;38;2;255;0;0m") }) // beats are pure red
        #expect(try #require(frames.last?.contains("\u{1B}[1;38;2;255;0;0m"))) // settles RED, not plain
    }
}
