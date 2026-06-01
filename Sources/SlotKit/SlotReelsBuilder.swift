/// A result builder that lets reels be declared as a block instead of an array literal,
/// so checks can be added conditionally (`if`) or generated in a loop (`for`).
///
/// ```swift
/// await SlotMachine.spin {
///     SlotReel(label: "BUILD") { compile() }
///     SlotReel(label: "TEST")  { try await runTests() }
///     if isMainBranch {
///         SlotReel(label: "DEPLOY") { try await deploy() }
///     }
/// }
/// ```
@resultBuilder
public enum SlotReelsBuilder {
    /// Flattens the reels (and reel groups) written in a block into one array.
    public static func buildBlock(_ parts: [SlotReel]...) -> [SlotReel] {
        parts.flatMap(\.self)
    }

    /// Lifts a bare `SlotReel` expression into the component type.
    public static func buildExpression(_ reel: SlotReel) -> [SlotReel] {
        [reel]
    }

    /// Splices an existing array of reels into the block.
    public static func buildExpression(_ reels: [SlotReel]) -> [SlotReel] {
        reels
    }

    /// Supports an `if` with no `else`: absent → no reels.
    public static func buildOptional(_ reels: [SlotReel]?) -> [SlotReel] {
        reels ?? []
    }

    /// Supports the `if` branch of an `if`/`else`.
    public static func buildEither(first reels: [SlotReel]) -> [SlotReel] {
        reels
    }

    /// Supports the `else` branch of an `if`/`else`.
    public static func buildEither(second reels: [SlotReel]) -> [SlotReel] {
        reels
    }

    /// Supports a `for` loop: each iteration contributes its reels.
    public static func buildArray(_ reels: [[SlotReel]]) -> [SlotReel] {
        reels.flatMap(\.self)
    }
}
