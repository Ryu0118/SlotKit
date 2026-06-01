/// Pure, side-effect-free rendering of a slot frame.
///
/// Given the symbols currently showing and their labels, it lays out the bordered
/// reel grid as plain lines (no ANSI, no I/O). This is the library's testable core;
/// animation and color are layered on top by ``SlotMachine``.
enum SlotRenderer {
    /// The number of lines ``frame(symbols:labels:theme:)`` produces for `theme`: a top
    /// border, `cellHeight` art rows, a bottom border, and a label row. This is the single
    /// source of truth the animation loop uses to reposition the cursor between frames —
    /// keep it in lockstep with `frame`'s layout below.
    static func lineCount(for theme: SlotTheme) -> Int {
        theme.cellHeight + 3 // top + art rows + bottom + label
    }

    /// Renders one full frame: a top border, `cellHeight` art rows, a bottom border,
    /// and a label row — each symbol boxed to `cellWidth`. Returns plain lines.
    static func frame(symbols: [SlotSymbol], labels: [String], theme: SlotTheme) -> [String] {
        let width = theme.cellWidth
        // Borders are identical per cell, so build one segment and repeat it.
        let top = String(repeating: "╔" + String(repeating: "═", count: width) + "╗", count: symbols.count)
        let bottom = String(repeating: "╚" + String(repeating: "═", count: width) + "╝", count: symbols.count)
        var artLines: [String] = []
        for row in 0 ..< theme.cellHeight {
            let line = symbols.map { "║" + centered($0.rows[row], width: width) + "║" }.joined()
            artLines.append(line)
        }
        let labelLine = labels.map { centered($0, width: width + 2) }.joined()
        return [top] + artLines + [bottom, labelLine]
    }

    /// Centers `text` in `width` columns; left-biased when padding is odd, clipped if too
    /// long. Width is measured in `Character` count, which equals display columns only for
    /// single-width characters — the themes ship ASCII/box-drawing art, so a custom theme
    /// using wide glyphs (emoji, CJK) would misalign.
    static func centered(_ text: String, width: Int) -> String {
        if text.count >= width { return String(text.prefix(width)) }
        let total = width - text.count
        let left = total / 2
        return String(repeating: " ", count: left) + text + String(repeating: " ", count: total - left)
    }
}
