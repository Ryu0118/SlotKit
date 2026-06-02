/// A result builder that lets grid columns be declared as a block instead of an array
/// literal, so columns can be added conditionally (`if`) or generated in a loop (`for`).
///
/// ```swift
/// await SlotMachine.spinGrid(rows: 3, paylines: .allLines(forSquare: 3)) {
///     GridReel(label: "①") { await draw3() }
///     GridReel(label: "②") { await draw3() }
///     GridReel(label: "③") { await draw3() }
/// }
/// ```
@resultBuilder
public enum GridReelsBuilder {
    /// Flattens the columns (and column groups) written in a block into one array.
    public static func buildBlock(_ parts: [GridReel]...) -> [GridReel] {
        parts.flatMap(\.self)
    }

    /// Lifts a bare `GridReel` expression into the component type.
    public static func buildExpression(_ column: GridReel) -> [GridReel] {
        [column]
    }

    /// Splices an existing array of columns into the block.
    public static func buildExpression(_ columns: [GridReel]) -> [GridReel] {
        columns
    }

    /// Supports an `if` with no `else`: absent → no columns.
    public static func buildOptional(_ columns: [GridReel]?) -> [GridReel] {
        columns ?? []
    }

    /// Supports the `if` branch of an `if`/`else`.
    public static func buildEither(first columns: [GridReel]) -> [GridReel] {
        columns
    }

    /// Supports the `else` branch of an `if`/`else`.
    public static func buildEither(second columns: [GridReel]) -> [GridReel] {
        columns
    }

    /// Supports a `for` loop: each iteration contributes its columns.
    public static func buildArray(_ columns: [[GridReel]]) -> [GridReel] {
        columns.flatMap(\.self)
    }
}
