import Foundation

/// Grid spins: an `R × C` machine where each column stops as a unit and wins pay along
/// declared ``Payline``s (rows + diagonals). The single-row ``spin`` / ``spinSymbols`` paths
/// are untouched — this is a separate path, so their rendering stays byte-identical.
public extension SlotMachine {
    /// Spins a grid of `columns`, each landing on `rows` symbols, and evaluates `paylines`.
    ///
    /// A column stops as a whole the instant its draw resolves; the caller decides when (e.g.
    /// on a keypress), so columns settle left to right. A win is any payline whose cells all
    /// show one symbol; the jackpot is a paying line of the theme's ``SlotTheme/jackpotIndex``.
    ///
    /// - Parameters:
    ///   - columns: the columns to spin, one draw each (`rows` indices, top to bottom).
    ///   - rows: the grid height.
    ///   - paylines: the lines a win is evaluated against (e.g. ``Payline/allLines(forSquare:)``).
    ///   - theme: visual + timing configuration; its ``SlotTheme/symbols`` are the faces.
    ///   - plain: force plain (`true`) or animated (`false`); `nil` auto-detects the terminal.
    /// - Returns: where every cell landed and which paylines paid.
    @discardableResult
    static func spinGrid(
        _ columns: [GridReel],
        rows: Int,
        paylines: [Payline],
        theme: SlotTheme = .default,
        plain: Bool? = nil,
    ) async -> GridSpinResult {
        let animate = !(plain ?? !Terminal.isInteractive)
        guard animate, !columns.isEmpty, rows > 0 else {
            return await runPlainGrid(columns, rows: rows, paylines: paylines, theme: theme)
        }
        return await runAnimatedGrid(columns, rows: rows, paylines: paylines, theme: theme)
    }

    /// Spins a grid declared as a ``GridReelsBuilder`` block — the same as the array overload,
    /// but columns can be added conditionally (`if`) or in a loop (`for`).
    ///
    /// - Parameters:
    ///   - rows: the grid height.
    ///   - paylines: the lines a win is evaluated against.
    ///   - theme: visual + timing configuration (defaults to ``SlotTheme/default``).
    ///   - plain: force plain (`true`) or animated (`false`); `nil` auto-detects.
    ///   - columns: a builder block producing the columns to spin.
    /// - Returns: where every cell landed and which paylines paid.
    @discardableResult
    static func spinGrid(
        rows: Int,
        paylines: [Payline],
        theme: SlotTheme = .default,
        plain: Bool? = nil,
        @GridReelsBuilder _ columns: @Sendable () -> [GridReel],
    ) async -> GridSpinResult {
        await spinGrid(columns(), rows: rows, paylines: paylines, theme: theme, plain: plain)
    }

    /// Pads a short draw (with index `0`) and clips a long one to `rows`, so a column always
    /// has exactly `rows` cells and a spin never traps on a miscounted draw.
    internal static func fit(_ indices: [Int], to rows: Int) -> [Int] {
        if indices.count == rows { return indices }
        if indices.count > rows { return Array(indices.prefix(rows)) }
        return indices + Array(repeating: 0, count: rows - indices.count)
    }

    /// Turns column-major landed indices (`[col][row]`) into row-major (`[row][col]`).
    internal static func transpose(_ landedColumns: [[Int]], rows: Int) -> [[Int]] {
        (0 ..< rows).map { row in
            landedColumns.map { column in row < column.count ? column[row] : 0 }
        }
    }

    private static func runPlainGrid(
        _ columns: [GridReel],
        rows: Int,
        paylines: [Payline],
        theme: SlotTheme,
    ) async -> GridSpinResult {
        var landedColumns: [[Int]] = []
        for column in columns {
            await landedColumns.append(Self.fit(column.landing(), to: rows))
        }
        return Self.result(landedColumns: landedColumns, columns: columns, rows: rows, paylines: paylines, theme: theme)
    }

    private static func runAnimatedGrid(
        _ columns: [GridReel],
        rows: Int,
        paylines: [Payline],
        theme: SlotTheme,
    ) async -> GridSpinResult {
        let results = GridResultBox(columns: columns.count, rows: rows)
        let labels = columns.map(\.label)
        await withTaskGroup(of: Void.self) { group in
            let minSpin = theme.minSpin
            for (index, column) in columns.enumerated() {
                group.addTask {
                    await revealColumn(column, index: index, into: results, rows: rows, minSpin: minSpin)
                }
            }
            group.addTask {
                await runGridDrawLoop(labels: labels, theme: theme, results: results, rows: rows)
            }
            await group.waitForAll()
        }
        let landedColumns = await results.landedColumns()
        let result = Self.result(
            landedColumns: landedColumns,
            columns: columns,
            rows: rows,
            paylines: paylines,
            theme: theme,
        )
        if !Task.isCancelled {
            await playGridFinale(result, rows: rows, labels: labels, theme: theme)
        }
        return result
    }

    private static func revealColumn(
        _ column: GridReel,
        index: Int,
        into results: GridResultBox,
        rows: Int,
        minSpin: Double,
    ) async {
        let landed = await Self.fit(column.landing(), to: rows)
        try? await Task.sleep(for: .seconds(minSpin))
        await results.reveal(index, indices: landed)
    }

    private static func result(
        landedColumns: [[Int]],
        columns: [GridReel],
        rows: Int,
        paylines: [Payline],
        theme: SlotTheme,
    ) -> GridSpinResult {
        let grid = Self.transpose(landedColumns, rows: rows)
        let cols = columns.count
        let winning = GridEvaluation.winningLines(grid: grid, paylines: paylines, rows: rows, cols: cols)
        return GridSpinResult(
            landed: grid,
            winningLines: winning,
            jackpotIndex: theme.jackpotIndex,
            columnLabels: columns.map(\.label),
        )
    }
}
