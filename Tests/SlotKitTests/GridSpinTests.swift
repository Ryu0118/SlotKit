@testable import SlotKit
import Testing

struct GridSpinTests {
    private static let lines = Payline.allLines(forSquare: 3)

    @Test
    func plainGridReportsLandedCellsRowMajor() async throws {
        let theme = try Fixtures.symbolTheme()
        // Three columns, each returning its three cells top-to-bottom.
        let columns = [
            GridReel { [0, 1, 2] },
            GridReel { [0, 1, 2] },
            GridReel { [0, 1, 2] },
        ]
        let result = await SlotMachine.spinGrid(columns, rows: 3, paylines: Self.lines, theme: theme, plain: true)
        // Row 0 is all column-tops (all 0), row 1 all 1, row 2 all 2 → every row matches.
        #expect(result.landed == [[0, 0, 0], [1, 1, 1], [2, 2, 2]])
        #expect(Set(result.winningLines.map(\.id)) == ["row-0", "row-1", "row-2"])
    }

    @Test
    func plainGridDetectsAJackpotLine() async throws {
        let theme = try Fixtures.symbolTheme() // jackpotIndex 0
        let columns = [GridReel { [0, 1, 2] }, GridReel { [0, 2, 1] }, GridReel { [0, 1, 1] }]
        let result = await SlotMachine.spinGrid(columns, rows: 3, paylines: Self.lines, theme: theme, plain: true)
        #expect(result.isJackpot) // row 0 is all 0 (the jackpot symbol)
        #expect(result.didWin)
    }

    @Test
    func plainGridWithNoLineReportsNoWin() async throws {
        let theme = try Fixtures.symbolTheme()
        // Columns chosen so no row and neither diagonal matches.
        let columns = [GridReel { [0, 0, 1] }, GridReel { [1, 2, 0] }, GridReel { [2, 1, 1] }]
        let result = await SlotMachine.spinGrid(columns, rows: 3, paylines: Self.lines, theme: theme, plain: true)
        #expect(result.landed == [[0, 1, 2], [0, 2, 1], [1, 0, 1]])
        #expect(!result.didWin)
        #expect(!result.isJackpot)
    }

    @Test
    func shortColumnIsPaddedAndLongColumnIsClipped() async throws {
        let theme = try Fixtures.symbolTheme()
        let columns = [GridReel { [1] }, GridReel { [2, 2, 2, 2, 2] }, GridReel { [0, 0, 0] }]
        let result = await SlotMachine.spinGrid(columns, rows: 3, paylines: Self.lines, theme: theme, plain: true)
        // col0 padded to [1,0,0], col1 clipped to [2,2,2], col2 [0,0,0]
        #expect(result.landed == [[1, 2, 0], [0, 2, 0], [0, 2, 0]])
    }

    @Test
    func emptyColumnsReturnEmptyResult() async throws {
        let theme = try Fixtures.symbolTheme()
        let result = await SlotMachine.spinGrid([], rows: 3, paylines: Self.lines, theme: theme, plain: true)
        #expect(result.landed.allSatisfy(\.isEmpty) || result.landed.isEmpty)
        #expect(!result.didWin)
    }

    @Test
    func animatedGridPreservesColumnOrderUnderStaggeredDraws() async throws {
        let theme = try Fixtures.symbolTheme()
        let columns = [
            GridReel(label: "SLOW") {
                try? await Task.sleep(for: .milliseconds(30))
                return [0, 0, 0]
            },
            GridReel(label: "FAST") { [1, 1, 1] },
        ]
        let result = await SlotMachine.spinGrid(columns, rows: 3, paylines: [.row(0)], theme: theme, plain: false)
        #expect(result.columnLabels == ["SLOW", "FAST"])
        #expect(result.landed[0] == [0, 1]) // col 0 stayed col 0 despite finishing later
    }

    @Test
    func cancellationPropagatesToColumnsOnAnimatedPath() async throws {
        let theme = try Fixtures.symbolTheme()
        let observed = ObservedFlag()
        let columns = [
            GridReel {
                do {
                    try await Task.sleep(for: .seconds(60))
                } catch {
                    await observed.set()
                    return [0, 0, 0]
                }
                return [0, 0, 0]
            },
        ]
        let task = Task {
            await SlotMachine.spinGrid(columns, rows: 3, paylines: [.row(0)], theme: theme, plain: false)
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
