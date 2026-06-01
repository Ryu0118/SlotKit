/// Colors a rendered line for animation frame `phase`.
///
/// The closure receives one already-laid-out line (borders, art, labels) plus the
/// current animation step, and returns the string to emit — typically the same text
/// wrapped in ANSI escapes. It must preserve the line's display width so the reel
/// grid stays aligned. Identity (`{ line, _ in line }`) yields plain output.
public typealias SlotColorizer = @Sendable (_ line: String, _ phase: Int) -> String

/// Built-in colorizers.
public enum SlotColorizers {
    /// Leaves every line untouched — plain, byte-stable output.
    public static let plain: SlotColorizer = { line, _ in line }

    /// Colors each character along a scrolling rainbow hue wheel (the arcade look).
    ///
    /// Spaces are left uncolored so width is preserved; `phase` scrolls the gradient.
    public static let rainbow: SlotColorizer = { line, phase in
        gradient(line, phase: phase)
    }

    private static let reset = "\u{1B}[0m"

    /// Wraps `text` character-by-character in truecolor escapes along the hue wheel.
    static func gradient(_ text: String, phase: Int, bold: Bool = true) -> String {
        let weight = bold ? "1;" : ""
        var out = ""
        out.reserveCapacity(text.count * 25) // ~one truecolor escape + char per non-space
        for (offset, character) in text.enumerated() {
            if character == " " {
                out.append(character)
                continue
            }
            let hue = Double((offset * 14 + phase) % 360)
            let (red, green, blue) = hueToRGB(hue)
            out += "\u{1B}[\(weight)38;2;\(red);\(green);\(blue)m\(character)"
        }
        return out + reset
    }

    private static func hueToRGB(_ hue: Double) -> (Int, Int, Int) {
        let sector = hue / 60.0
        let chroma = 1.0
        let secondary = chroma * (1 - abs(sector.truncatingRemainder(dividingBy: 2) - 1))
        let (red, green, blue): (Double, Double, Double) = switch Int(sector) % 6 {
        case 0: (chroma, secondary, 0)
        case 1: (secondary, chroma, 0)
        case 2: (0, chroma, secondary)
        case 3: (0, secondary, chroma)
        case 4: (secondary, 0, chroma)
        default: (chroma, 0, secondary)
        }
        return (Int(red * 255), Int(green * 255), Int(blue * 255))
    }
}
