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
