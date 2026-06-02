@testable import SlotKit
import Testing

struct GridRendererTests {
    private static func theme() throws -> SlotTheme {
        try Fixtures.symbolTheme() // cellWidth 3, cellHeight 1, three symbols
    }

    private static func cell(_ char: String) -> SlotSymbol {
        SlotSymbol(rows: [" \(char) "])
    }

    @Test
    func singleRowGridIsByteIdenticalToSlotRendererUnlabeled() throws {
        let theme = try Self.theme()
        let symbols = [Self.cell("7"), Self.cell("C"), Self.cell("B")]
        let grid = GridRenderer.frame(grid: [symbols], labels: [nil, nil, nil], theme: theme)
        let single = SlotRenderer.frame(symbols: symbols, labels: [nil, nil, nil], theme: theme)
        #expect(grid == single)
    }

    @Test
    func singleRowGridIsByteIdenticalToSlotRendererLabeled() throws {
        let theme = try Self.theme()
        let symbols = [Self.cell("7"), Self.cell("C")]
        let labels: [String?] = ["A", "B"]
        let grid = GridRenderer.frame(grid: [symbols], labels: labels, theme: theme)
        let single = SlotRenderer.frame(symbols: symbols, labels: labels, theme: theme)
        #expect(grid == single)
    }

    @Test(arguments: [1, 2, 3, 5])
    func lineCountMatchesFrameOutputUnlabeled(rows: Int) throws {
        let theme = try Self.theme()
        let grid = Array(repeating: [Self.cell("7"), Self.cell("C")], count: rows)
        let lines = GridRenderer.frame(grid: grid, labels: [nil, nil], theme: theme)
        let counted = GridRenderer.lineCount(rows: rows, theme: theme, hasLabels: false)
        #expect(lines.count == counted)
    }

    @Test(arguments: [1, 2, 3, 5])
    func lineCountMatchesFrameOutputLabeled(rows: Int) throws {
        let theme = try Self.theme()
        let grid = Array(repeating: [Self.cell("7"), Self.cell("C")], count: rows)
        let lines = GridRenderer.frame(grid: grid, labels: ["x", "y"], theme: theme)
        let counted = GridRenderer.lineCount(rows: rows, theme: theme, hasLabels: true)
        #expect(lines.count == counted)
    }

    @Test
    func adjacentRowBandsShareATJunctionRule() throws {
        let theme = try Self.theme() // cellHeight 1
        let grid = [[Self.cell("7")], [Self.cell("C")]] // 2 rows, 1 col
        let lines = GridRenderer.frame(grid: grid, labels: [nil], theme: theme)
        // top, art, RULE, art, bottom
        #expect(lines.count == 5)
        #expect(lines[0].hasPrefix("╔"))
        #expect(lines[2].hasPrefix("╠")) // the shared interior rule
        #expect(lines[4].hasPrefix("╚"))
    }

    @Test
    func everyLineHasEqualWidth() throws {
        let theme = try Self.theme()
        let grid = [[Self.cell("7"), Self.cell("C")], [Self.cell("B"), Self.cell("7")]]
        let lines = GridRenderer.frame(grid: grid, labels: [nil, nil], theme: theme)
        let widths = Set(lines.map(\.count))
        #expect(widths.count == 1) // all rendered lines share one width
    }
}
