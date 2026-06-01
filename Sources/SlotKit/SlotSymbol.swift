/// A single multi-row ASCII-art face shown in a reel window.
///
/// Every symbol in a theme must share the same dimensions (`cellHeight` rows, each
/// `cellWidth` display columns wide). Construct symbols through ``SlotTheme`` so the
/// dimensions are validated up front rather than clipping silently at render time.
public struct SlotSymbol: Sendable, Equatable {
    /// The art rows, top to bottom.
    public let rows: [String]

    /// Creates a symbol from its raw rows. Prefer building symbols via ``SlotTheme``,
    /// which validates that every symbol matches the theme's cell dimensions.
    public init(rows: [String]) {
        self.rows = rows
    }
}
