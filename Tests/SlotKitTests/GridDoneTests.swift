@testable import SlotKit
import Testing

struct GridFitTests {
    @Test(arguments: [
        ([1, 2, 3], 3, [1, 2, 3]), // exact
        ([1], 3, [1, 0, 0]), // padded with 0
        ([1, 2, 3, 4, 5], 3, [1, 2, 3]), // clipped
        ([], 2, [0, 0]), // empty padded
    ])
    func fitPadsAndClipsToRowCount(indices: [Int], rows: Int, expected: [Int]) {
        #expect(SlotMachine.fit(indices, to: rows) == expected)
    }

    @Test
    func transposeTurnsColumnMajorIntoRowMajor() {
        let columns = [[0, 1, 2], [3, 4, 5]] // 2 columns of 3 cells
        #expect(SlotMachine.transpose(columns, rows: 3) == [[0, 3], [1, 4], [2, 5]])
    }
}

struct GridResultBoxTests {
    @Test
    func notDoneUntilEveryColumnRevealed() async throws {
        let box = GridResultBox(columns: 2, rows: 2)
        let theme = try? Fixtures.symbolTheme()
        let before = try await box.frameState(step: 0, theme: #require(theme))
        #expect(!before.done)
        await box.reveal(0, indices: [0, 0])
        let mid = try await box.frameState(step: 0, theme: #require(theme))
        #expect(!mid.done)
        await box.reveal(1, indices: [1, 1])
        let after = try await box.frameState(step: 0, theme: #require(theme))
        #expect(after.done)
    }

    @Test
    func revealPadsAndClipsTheColumn() async {
        let box = GridResultBox(columns: 2, rows: 3)
        await box.reveal(0, indices: [2]) // short → padded
        await box.reveal(1, indices: [1, 1, 1, 1]) // long → clipped
        let landed = await box.landedColumns()
        #expect(landed == [[2, 0, 0], [1, 1, 1]])
    }
}
