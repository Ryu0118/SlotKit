@testable import SlotKit
import Testing

struct SlotThemeValidationTests {
    @Test
    func defaultThemeBuildsWithConsistentDimensions() {
        let theme = SlotTheme.default
        #expect(theme.cellWidth == 10)
        #expect(theme.cellHeight == 5)
        for symbol in theme.spinning + [theme.win, theme.lose] {
            #expect(symbol.rows.count == theme.cellHeight)
            for row in symbol.rows {
                #expect(row.count == theme.cellWidth)
            }
        }
    }

    @Test
    func wrongRowCountThrows() {
        #expect(throws: SlotThemeError.self) {
            try SlotTheme.make { draft in
                draft.cellWidth = 3
                draft.cellHeight = 2
                draft.win = SlotSymbol(rows: ["abc"]) // 1 row, expected 2
                draft.lose = SlotSymbol(rows: ["abc", "def"])
                draft.spinning = [SlotSymbol(rows: ["abc", "def"])]
            }
        }
    }

    @Test
    func wrongRowWidthThrows() {
        #expect(throws: SlotThemeError.self) {
            try SlotTheme.make { draft in
                draft.cellWidth = 3
                draft.cellHeight = 1
                draft.win = SlotSymbol(rows: ["abcd"]) // 4 wide, expected 3
                draft.lose = SlotSymbol(rows: ["abc"])
                draft.spinning = [SlotSymbol(rows: ["abc"])]
            }
        }
    }

    @Test
    func noSpinningSymbolsThrows() {
        #expect(throws: SlotThemeError.noSpinningSymbols) {
            try SlotTheme.make { draft in
                draft.cellWidth = 3
                draft.cellHeight = 1
                draft.win = SlotSymbol(rows: ["abc"])
                draft.lose = SlotSymbol(rows: ["abc"])
                draft.spinning = []
            }
        }
    }
}

struct SlotRendererTests {
    private func makeTheme() throws -> SlotTheme {
        try SlotTheme.make { draft in
            draft.cellWidth = 3
            draft.cellHeight = 1
            draft.win = SlotSymbol(rows: ["WWW"])
            draft.lose = SlotSymbol(rows: ["LLL"])
            draft.spinning = [SlotSymbol(rows: ["..."])]
        }
    }

    @Test
    func frameLaysOutBordersArtAndLabels() throws {
        let theme = try makeTheme()
        let lines = SlotRenderer.frame(
            symbols: [SlotSymbol(rows: ["WWW"]), SlotSymbol(rows: ["LLL"])],
            labels: ["A", "B"],
            theme: theme,
        )
        // top + 1 art row + bottom + label row = 4 lines.
        #expect(lines.count == 4)
        #expect(lines[0] == "╔═══╗╔═══╗")
        #expect(lines[1] == "║WWW║║LLL║")
        #expect(lines[2] == "╚═══╝╚═══╝")
        // labels centered in cellWidth + 2 (= 5) columns each.
        #expect(lines[3] == "  A    B  ")
    }

    @Test
    func everyLineSharesWidth() throws {
        let theme = try makeTheme()
        let lines = SlotRenderer.frame(
            symbols: [SlotSymbol(rows: ["WWW"]), SlotSymbol(rows: ["..."])],
            labels: ["X", "Y"],
            theme: theme,
        )
        let widths = Set(lines.map(\.count))
        #expect(widths.count == 1)
    }

    @Test
    func centeredClipsOverlongText() {
        #expect(SlotRenderer.centered("toolong", width: 3) == "too")
        #expect(SlotRenderer.centered("x", width: 5) == "  x  ")
    }

    @Test
    func lineCountMatchesFrameOutput() throws {
        // SSoT guard: the count the animation loop uses to reposition the cursor must
        // equal the lines `frame` actually emits, so layout edits can't silently desync.
        let theme = try makeTheme()
        let lines = SlotRenderer.frame(
            symbols: [SlotSymbol(rows: ["WWW"])],
            labels: ["A"],
            theme: theme,
        )
        #expect(lines.count == SlotRenderer.lineCount(for: theme))
    }
}

struct SlotColorizerTests {
    @Test
    func plainIsIdentity() {
        #expect(SlotColorizers.plain("hello", 0) == "hello")
        #expect(SlotColorizers.plain("a b c", 42) == "a b c")
    }

    @Test
    func rainbowWrapsAnsiButKeepsCharacters() {
        let colored = SlotColorizers.rainbow("hi", 0)
        #expect(colored.contains("\u{1B}["))
        #expect(colored.contains("h"))
        #expect(colored.contains("i"))
        #expect(colored.hasSuffix("\u{1B}[0m"))
    }

    @Test
    func rainbowLeavesSpacesUncolored() {
        // A run of only spaces should come back unchanged (plus the trailing reset).
        let colored = SlotColorizers.rainbow("   ", 0)
        #expect(colored == "   \u{1B}[0m")
    }
}

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

// MARK: - Shared fixtures

/// Shared test fixtures.
enum Fixtures {
    /// A small, instantly-resolving theme for animated-path tests: `minSpin = 0` and a tiny
    /// frame interval so `spin(_, plain: false)` returns without real-time delay, plus a
    /// finale so the all-win path exercises the flourish branch.
    static func fastTheme() throws -> SlotTheme {
        try SlotTheme.make { draft in
            draft.cellWidth = 3
            draft.cellHeight = 1
            draft.win = SlotSymbol(rows: ["WIN"])
            draft.lose = SlotSymbol(rows: ["los"])
            draft.spinning = [SlotSymbol(rows: ["..."]), SlotSymbol(rows: ["oOo"])]
            draft.frameInterval = 0.001
            draft.minSpin = 0
            draft.colorize = SlotColorizers.plain
            draft.finale = SlotTheme.SlotFinale(text: "WIN", frames: 1, interval: 0.001)
        }
    }
}

// MARK: - SlotReelsBuilder DSL

struct SlotReelsBuilderTests {
    @Test
    func plainBlockProducesReelsInOrder() async {
        let result = await SlotMachine.spin(plain: true) {
            SlotReel(label: "A") { true }
            SlotReel(label: "B") { false }
        }
        #expect(result.outcomes == [
            SlotOutcome(label: "A", passed: true),
            SlotOutcome(label: "B", passed: false),
        ])
    }

    @Test
    func falseIfDropsItsReel() async {
        let includeDeploy = false
        let result = await SlotMachine.spin(plain: true) {
            SlotReel(label: "BUILD") { true }
            if includeDeploy {
                SlotReel(label: "DEPLOY") { true }
            }
        }
        #expect(result.outcomes.map(\.label) == ["BUILD"])
    }

    @Test
    func trueIfKeepsItsReel() async {
        let includeDeploy = true
        let result = await SlotMachine.spin(plain: true) {
            SlotReel(label: "BUILD") { true }
            if includeDeploy {
                SlotReel(label: "DEPLOY") { true }
            }
        }
        #expect(result.outcomes.map(\.label) == ["BUILD", "DEPLOY"])
    }

    @Test(arguments: [true, false])
    func ifElseSelectsTheRightBranch(useFastPath: Bool) async {
        let result = await SlotMachine.spin(plain: true) {
            if useFastPath {
                SlotReel(label: "FAST") { true }
            } else {
                SlotReel(label: "SLOW") { true }
            }
        }
        #expect(result.outcomes.map(\.label) == [useFastPath ? "FAST" : "SLOW"])
    }

    @Test
    func forLoopContributesOneReelPerIteration() async {
        let packages = ["core", "ui", "net"]
        let result = await SlotMachine.spin(plain: true) {
            for package in packages {
                SlotReel(label: package) { true }
            }
        }
        #expect(result.outcomes.map(\.label) == packages)
    }

    @MainActor
    @Test
    func builderIsUsableFromMainActor() async {
        // `@main` CLI entry points and SwiftUI callers are main-actor-isolated; the builder
        // closure must be `@Sendable` so the block compiles from that context (the other
        // tests run nonisolated and can't catch this).
        let result = await SlotMachine.spin(plain: true) {
            SlotReel(label: "A") { true }
        }
        #expect(result.outcomes.map(\.label) == ["A"])
    }

    @Test
    func existingArrayCanBeSplicedIn() async {
        let base = [SlotReel(label: "X") { true }, SlotReel(label: "Y") { true }]
        let result = await SlotMachine.spin(plain: true) {
            base
            SlotReel(label: "Z") { true }
        }
        #expect(result.outcomes.map(\.label) == ["X", "Y", "Z"])
    }
}

// MARK: - SlotResult

struct SlotResultTests {
    @Test(arguments: [
        ([true, true, true], true),
        ([true, false, true], false),
        ([false, false], false),
        ([], true), // vacuously true
    ])
    func allPassedReflectsEveryOutcome(outcomes: [Bool], expected: Bool) {
        let result = SlotResult(outcomes: outcomes.enumerated().map { index, passed in
            SlotOutcome(label: "\(index)", passed: passed)
        })
        #expect(result.allPassed == expected)
    }
}

// MARK: - SlotMachine animated path (plain: false)

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

// MARK: - SlotRenderer.spinningFace

struct SpinningFaceTests {
    private let pool = [
        SlotSymbol(rows: ["a"]),
        SlotSymbol(rows: ["b"]),
        SlotSymbol(rows: ["c"]),
    ]

    @Test(arguments: [
        (0, 0, "a"), // step 0, reel 0
        (1, 0, "b"), // step advances the face
        (2, 0, "c"),
        (3, 0, "a"), // wraps around the pool
        (0, 1, "a"), // reel 1 offset by index*3 == 3, wraps back to a
        (0, 2, "a"), // reel 2 offset by index*3 == 6, wraps back to a
        (1, 1, "b"), // (1 + 3) % 3 == 1
    ])
    func spinningFaceCyclesByStepAndIndex(step: Int, index: Int, expected: String) {
        let face = SlotRenderer.spinningFace(in: pool, step: step, index: index)
        #expect(face.rows == [expected])
    }

    @Test
    func adjacentReelsAreOffsetAtSameStep() {
        // index*3 with a 3-element pool means reels 0/1/2 all land on the same face only
        // because 3 % 3 == 0; a 2-element pool should stagger them.
        let twoPool = [SlotSymbol(rows: ["x"]), SlotSymbol(rows: ["y"])]
        let reel0 = SlotRenderer.spinningFace(in: twoPool, step: 0, index: 0)
        let reel1 = SlotRenderer.spinningFace(in: twoPool, step: 0, index: 1)
        #expect(reel0.rows == ["x"]) // (0 + 0) % 2
        #expect(reel1.rows == ["y"]) // (0 + 3) % 2 == 1
    }
}

// MARK: - SlotColorizer.gradient structure

struct SlotGradientTests {
    @Test
    func hueWrapsEvery360Phases() {
        // phase and phase+360 feed the same hue, so the colored output is identical.
        #expect(SlotColorizers.gradient("hello", phase: 7) == SlotColorizers.gradient("hello", phase: 367))
    }

    @Test
    func boldAndNonBoldDifferInWeightPrefix() {
        let bold = SlotColorizers.gradient("x", phase: 0, bold: true)
        let plain = SlotColorizers.gradient("x", phase: 0, bold: false)
        #expect(bold.contains("[1;38;2;"))
        #expect(plain.contains("[38;2;"))
        #expect(!plain.contains("[1;38;2;"))
    }

    @Test
    func emptyStringIsJustTheReset() {
        #expect(SlotColorizers.gradient("", phase: 0) == "\u{1B}[0m")
    }

    @Test(arguments: [0, 60, 120, 180, 240, 300, 359])
    func everyHueSectorProducesValidRGB(phase: Int) {
        // Walk one character across each hue sector; output must stay well-formed
        // (an escape per non-space char, terminated by the reset) for every sector.
        let colored = SlotColorizers.gradient("X", phase: phase)
        #expect(colored.contains("\u{1B}[1;38;2;"))
        #expect(colored.contains("X"))
        #expect(colored.hasSuffix("\u{1B}[0m"))
    }
}

// MARK: - SlotRenderer.centered edge cases

struct CenteredEdgeCaseTests {
    @Test(arguments: [
        ("x", 5, "  x  "), // odd padding, left-biased
        ("xy", 5, " xy  "), // odd padding, extra space on the right
        ("xy", 4, " xy "), // even padding
        ("abc", 3, "abc"), // exact fit, untouched
        ("toolong", 3, "too"), // clipped to width
        ("", 3, "   "), // empty pads to all spaces
    ])
    func centeredPadsAndClips(text: String, width: Int, expected: String) {
        #expect(SlotRenderer.centered(text, width: width) == expected)
    }
}
