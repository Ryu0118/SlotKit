@testable import SlotKit
import Testing

struct GridSkillTests {
    private static let lines = Payline.allLines(forSquare: 3)

    /// A theme whose spinning pool is exactly its symbols, so a stopped face maps cleanly
    /// back to a symbol index.
    private static func theme() throws -> SlotTheme {
        try Fixtures.symbolTheme()
    }

    @Test
    func plainSkillSettlesEveryColumnOnIndexZero() async throws {
        let theme = try Self.theme()
        let columns = [SkillReel {}, SkillReel {}, SkillReel {}]
        let result = await SlotMachine.spinGridSkill(columns, rows: 3, paylines: Self.lines, theme: theme, plain: true)
        #expect(result.landed == [[0, 0, 0], [0, 0, 0], [0, 0, 0]])
        // All-zero is the jackpot symbol on every line.
        #expect(result.isJackpot)
    }

    @Test
    func emptyColumnsReturnEmptyResult() async throws {
        let theme = try Self.theme()
        let result = await SlotMachine.spinGridSkill([], rows: 3, paylines: Self.lines, theme: theme, plain: true)
        #expect(!result.didWin)
    }

    @Test
    func stopAtCurrentStepLandsOnTheShowingFace() async throws {
        // Drive a box directly: at a known step, stopping a column must land each cell on the
        // symbol the spinning pool shows at that step — the heart of the skill stop.
        let theme = try Self.theme() // symbols == spinning == [7, C, B]
        let box = GridResultBox(columns: 2, rows: 3)
        _ = await box.frameState(step: 4, theme: theme) // record lastStep = 4
        await box.stopAtCurrentStep(0, theme: theme)
        let landed = await box.landedColumns()
        let expected = (0 ..< 3).map { row -> Int in
            let face = SlotRenderer.spinningFace(in: theme.spinning, step: 4, index: 0 * 3 + row)
            return theme.symbols.firstIndex(of: face) ?? 0
        }
        #expect(landed[0] == expected)
    }

    @Test
    func animatedSkillPreservesColumnOrder() async throws {
        let theme = try Self.theme()
        let columns = [
            SkillReel(label: "A") {},
            SkillReel(label: "B") {},
        ]
        let result = await SlotMachine.spinGridSkill(columns, rows: 3, paylines: [.row(0)], theme: theme, plain: false)
        #expect(result.columnLabels == ["A", "B"])
        #expect(result.landed.count == 3) // 3 rows
        #expect(result.landed[0].count == 2) // 2 columns
    }

    @Test
    func cancellationPropagatesToColumns() async throws {
        let theme = try Self.theme()
        let observed = ObservedFlag()
        let columns = [
            SkillReel {
                do {
                    try await Task.sleep(for: .seconds(60))
                } catch {
                    await observed.set()
                }
            },
        ]
        let task = Task {
            await SlotMachine.spinGridSkill(columns, rows: 3, paylines: [.row(0)], theme: theme, plain: false)
        }
        try? await Task.sleep(for: .milliseconds(50))
        task.cancel()
        _ = await task.value
        #expect(await observed.value)
    }

    private actor ObservedFlag {
        private(set) var value = false
        func set() {
            value = true
        }
    }
}
