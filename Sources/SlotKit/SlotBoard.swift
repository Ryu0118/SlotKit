/// A static, browsable board built on top of the pure ``SlotRenderer`` layout.
///
/// ``SlotRenderer/frame(symbols:labels:theme:)`` lays the reels out as plain lines with **no
/// ANSI** — that purity is the library's test surface, and color is layered on afterward by
/// ``SlotMachine``. Color and selection highlight are the same category: presentation concerns, not
/// layout. So both live here, not in ``SlotRenderer``. ``frame(symbols:labels:theme:highlight:phase:)``
/// delegates the layout to ``SlotRenderer``, applies the theme's colorizer (the arcade rainbow by
/// default), and reverse-video-wraps the highlighted cell, so a caller driving its own interactive
/// board (arrowing across reels) gets the whole picture — box art, faces, labels, color, and the
/// cursor — from SlotKit, with no duplicated drawing on their side.
public enum SlotBoard {
    private static let reverseOn = "\u{1B}[7m"
    private static let reverseOff = "\u{1B}[0m"

    /// Lays out a horizontal board, colors it with the theme's colorizer at animation `phase`, and
    /// (when `highlight` is non-nil) reverse-video-wraps that cell's whole box (every line: top
    /// border, art rows, bottom border, and the label row when present) so it reads as the selection.
    ///
    /// Layout is delegated to ``SlotRenderer/frame(symbols:labels:theme:)`` unchanged. Color is the
    /// theme's `colorize` (identity for a plain theme, so a plain theme yields plain output). The
    /// highlighted cell is left **un-colored** and reverse-video-wrapped — the cleanest "selected"
    /// look, and it sidesteps mixing reverse-video with the colorizer's truecolor SGR inside one
    /// cell. Each cell occupies `cellWidth + 2` display columns (the two box-border columns
    /// included) and cells are adjacent, so the highlighted cell spans
    /// `[highlight * (cellWidth+2), (highlight+1) * (cellWidth+2))`. The span is sliced by
    /// `Character` offset — the box-drawing glyphs are multi-byte, so a byte slice would split one.
    ///
    /// - Parameters:
    ///   - symbols: the face showing on each reel, left to right.
    ///   - labels: per-reel labels (a `nil` cell renders blank); the label row is dropped entirely
    ///     when every label is `nil`, matching ``SlotRenderer``.
    ///   - theme: supplies the cell geometry and the colorizer.
    ///   - highlight: the reel index to mark as selected, or `nil` for a plain board.
    ///   - phase: the animation phase fed to the colorizer (scrolls the gradient). Defaults to `0`.
    /// - Returns: the board's lines, ready to print.
    public static func frame(
        symbols: [SlotSymbol],
        labels: [String?],
        theme: SlotTheme,
        highlight: Int? = nil,
        phase: Int = 0,
    ) -> [String] {
        let lines = SlotRenderer.frame(symbols: symbols, labels: labels, theme: theme)
        guard let highlight, highlight >= 0, highlight < symbols.count else {
            // No selection: color every line whole, so the gradient runs unbroken across the board.
            return lines.map { theme.colorize($0, phase) }
        }
        let cellWidth = theme.cellWidth + 2
        let start = highlight * cellWidth
        return lines.map { line in
            colorizedWithHighlight(line, start: start, width: cellWidth, colorize: theme.colorize, phase: phase)
        }
    }

    /// The face a spinning reel shows at animation `step`. A caller driving its own board (rather
    /// than ``SlotMachine/spin(_:theme:plain:)``) uses this to pick each spinning reel's current
    /// face, so the cycling matches what the built-in animation would show. `pool` is the theme's
    /// `spinning` faces; `index` offsets each reel so adjacent reels don't move in lockstep.
    public static func spinningFace(in pool: [SlotSymbol], step: Int, index: Int) -> SlotSymbol {
        SlotRenderer.spinningFace(in: pool, step: step, index: index)
    }

    /// Colors `line` around a reverse-video highlight at `[start, start+width)` (measured in
    /// `Character`s, since box-drawing glyphs are multi-byte). The before/after segments run through
    /// `colorize`; the highlighted cell is left un-colored and reverse-video-wrapped. A line that
    /// doesn't reach the span (shouldn't happen for a well-formed frame) is colored whole.
    ///
    /// Coloring the segments separately restarts the colorizer's per-character offset at the cell
    /// boundary, so the gradient has a small seam at the cursor — an accepted trade for keeping the
    /// selected cell a clean reverse-video block rather than reverse-over-truecolor.
    private static func colorizedWithHighlight(
        _ line: String,
        start: Int,
        width: Int,
        colorize: SlotColorizer,
        phase: Int,
    ) -> String {
        let chars = Array(line)
        guard start < chars.count else { return colorize(line, phase) }
        let end = min(start + width, chars.count)
        let before = colorize(String(chars[0 ..< start]), phase)
        let cell = String(chars[start ..< end])
        let after = colorize(String(chars[end ..< chars.count]), phase)
        return before + reverseOn + cell + reverseOff + after
    }
}
