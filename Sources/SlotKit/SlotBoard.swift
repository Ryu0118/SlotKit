/// A static, browsable board built on top of the pure ``SlotRenderer`` layout.
///
/// ``SlotRenderer/frame(symbols:labels:theme:)`` lays the reels out as plain lines with **no
/// ANSI** — that purity is the library's test surface, and color is layered on afterward by
/// ``SlotMachine``. Selection highlight is the same category as color: a presentation concern, not
/// layout. So it lives here, not in ``SlotRenderer``. ``frame(symbols:labels:theme:highlight:)``
/// delegates the layout to ``SlotRenderer`` and then reverse-video-wraps the highlighted cell, so a
/// caller driving its own interactive board (arrowing across reels) gets the whole picture — box
/// art, faces, labels, and the cursor — from SlotKit, with no duplicated drawing on their side.
public enum SlotBoard {
    private static let reverseOn = "\u{1B}[7m"
    private static let reverseOff = "\u{1B}[0m"

    /// Lays out a horizontal board and, when `highlight` is non-nil, reverse-video-wraps that
    /// cell's whole box (every line: top border, art rows, bottom border, and the label row when
    /// present) so it reads as the selection.
    ///
    /// Layout is delegated to ``SlotRenderer/frame(symbols:labels:theme:)`` unchanged; this only
    /// wraps a fixed column span per line. Each cell occupies `cellWidth + 2` display columns
    /// (the two box-border columns included) and cells are adjacent, so the highlighted cell spans
    /// `[highlight * (cellWidth+2), (highlight+1) * (cellWidth+2))`. The span is sliced by
    /// `Character` offset — the box-drawing glyphs are multi-byte, so a byte slice would split one.
    ///
    /// - Parameters:
    ///   - symbols: the face showing on each reel, left to right.
    ///   - labels: per-reel labels (a `nil` cell renders blank); the label row is dropped entirely
    ///     when every label is `nil`, matching ``SlotRenderer``.
    ///   - theme: supplies the cell geometry.
    ///   - highlight: the reel index to mark as selected, or `nil` for a plain board.
    /// - Returns: the board's lines, ready to print. With `highlight` `nil` the result is identical
    ///   to ``SlotRenderer/frame(symbols:labels:theme:)``.
    public static func frame(
        symbols: [SlotSymbol],
        labels: [String?],
        theme: SlotTheme,
        highlight: Int? = nil,
    ) -> [String] {
        let lines = SlotRenderer.frame(symbols: symbols, labels: labels, theme: theme)
        guard let highlight, highlight >= 0, highlight < symbols.count else { return lines }
        let cellWidth = theme.cellWidth + 2
        let start = highlight * cellWidth
        return lines.map { line in highlightSpan(line, start: start, width: cellWidth) }
    }

    /// The face a spinning reel shows at animation `step`. A caller driving its own board (rather
    /// than ``SlotMachine/spin(_:theme:plain:)``) uses this to pick each spinning reel's current
    /// face, so the cycling matches what the built-in animation would show. `pool` is the theme's
    /// `spinning` faces; `index` offsets each reel so adjacent reels don't move in lockstep.
    public static func spinningFace(in pool: [SlotSymbol], step: Int, index: Int) -> SlotSymbol {
        SlotRenderer.spinningFace(in: pool, step: step, index: index)
    }

    /// Reverse-video-wraps `[start, start+width)` of `line`, measured in `Character`s. Lines that
    /// don't reach the span (shouldn't happen for a well-formed frame) are returned unchanged.
    private static func highlightSpan(_ line: String, start: Int, width: Int) -> String {
        let chars = Array(line)
        guard start < chars.count else { return line }
        let end = min(start + width, chars.count)
        let before = String(chars[0 ..< start])
        let cell = String(chars[start ..< end])
        let after = String(chars[end ..< chars.count])
        return before + reverseOn + cell + reverseOff + after
    }
}
