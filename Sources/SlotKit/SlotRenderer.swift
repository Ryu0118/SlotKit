/// Pure, side-effect-free rendering of a slot frame.
///
/// Given the symbols currently showing and their labels, it lays out the bordered
/// reel grid as plain lines (no ANSI, no I/O). This is the library's testable core;
/// animation and color are layered on top by ``SlotMachine``.
enum SlotRenderer {
    /// Renders one full frame: a top border, `cellHeight` art rows, a bottom border,
    /// and a label row — each symbol boxed to `cellWidth`. Returns plain lines.
    static func frame(symbols: [SlotSymbol], labels: [String], theme: SlotTheme) -> [String] {
        let width = theme.cellWidth
        let top = symbols.map { _ in "╔" + String(repeating: "═", count: width) + "╗" }.joined()
        let bottom = symbols.map { _ in "╚" + String(repeating: "═", count: width) + "╝" }.joined()
        var artLines: [String] = []
        for row in 0 ..< theme.cellHeight {
            let line = symbols.map { "║" + pad($0.rows[row], width: width) + "║" }.joined()
            artLines.append(line)
        }
        let labelLine = labels.map { centered($0, width: width + 2) }.joined()
        return [top] + artLines + [bottom, labelLine]
    }

    /// Centers `text` in a field of `width`, clipping if it is too long.
    static func pad(_ text: String, width: Int) -> String {
        centered(text, width: width)
    }

    /// Centers `text` in `width` columns; left-biased when padding is odd.
    static func centered(_ text: String, width: Int) -> String {
        if text.count >= width { return String(text.prefix(width)) }
        let total = width - text.count
        let left = total / 2
        return String(repeating: " ", count: left) + text + String(repeating: " ", count: total - left)
    }
}
