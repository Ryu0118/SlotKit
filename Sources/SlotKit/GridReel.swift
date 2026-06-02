/// One column of a grid spin — the unit that stops as a whole.
///
/// A real slot stops column by column, all the cells in a column revealing together. A
/// `GridReel`'s async `landing` draws the landed symbol index for each of the grid's rows,
/// **top to bottom**. The grid reveals the whole column the instant its draw resolves; the
/// caller decides *when* that is (e.g. on a keypress), so reels stop left to right.
public struct GridReel: Sendable {
    /// The caption shown beneath the column, or `nil` for none.
    public let label: String?
    /// The async draw → one symbol index per row, top to bottom. The grid pads a short
    /// result (with index `0`) and clips a long one to the row count, so a spin never traps.
    public let landing: @Sendable () async -> [Int]

    /// Creates a labeled column with its async draw.
    public init(label: String, landing: @escaping @Sendable () async -> [Int]) {
        self.label = label
        self.landing = landing
    }

    /// Creates an unlabeled column — just a spinning column and its async draw.
    public init(_ landing: @escaping @Sendable () async -> [Int]) {
        label = nil
        self.landing = landing
    }
}
