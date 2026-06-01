import Foundation
import SlotKit

/// A tiny demo so the animation can be watched by eye. Each "check" just sleeps a
/// fixed amount and returns a fixed result, so reels resolve at staggered times.
///
/// Run:  swift run slotkit-demo            (animated, all win → jackpot)
///       swift run slotkit-demo --fail     (one reel loses, no jackpot)
///       swift run slotkit-demo | cat      (plain, piped output)
///       swift run slotkit-demo --custom   (a custom 2-symbol theme)
@main
enum Demo {
    static func main() async throws {
        let arguments = Set(CommandLine.arguments.dropFirst())
        let forceFail = arguments.contains("--fail")
        let custom = arguments.contains("--custom")

        let theme: SlotTheme = try custom ? customTheme() : .default

        // Declared as a builder block to showcase @SlotReelsBuilder.
        let result = await SlotMachine.spin(theme: theme) {
            delayedCheck("BUILD", passes: true, milliseconds: 400)
            delayedCheck("TEST", passes: true, milliseconds: 900)
            delayedCheck("LINT", passes: !forceFail, milliseconds: 1500)
            delayedCheck("DEPLOY", passes: true, milliseconds: 2100)
        }

        for outcome in result.outcomes {
            emitLine("\(outcome.label): \(outcome.passed ? "pass" : "fail")")
        }
        emitLine(result.allPassed ? "All reels passed." : "Some reels failed.")
    }

    private static func delayedCheck(_ label: String, passes: Bool, milliseconds: Int) -> SlotReel {
        SlotReel(label: label) {
            try? await Task.sleep(for: .milliseconds(milliseconds))
            return passes
        }
    }

    /// A loud money-slot theme. Every symbol row is exactly 9 single-width columns
    /// (ASCII + block elements) so it stays grid-aligned. The dopamine comes from
    /// `neonGold` (a custom colorizer; ANSI = zero display width) plus the all-win flash.
    /// `throws` (not `try?`) so a dimension slip names the offending symbol/row.
    private static func customTheme() throws -> SlotTheme {
        try SlotTheme.make { draft in
            draft.cellWidth = 9
            draft.cellHeight = 5
            draft.colorize = neonGold
            draft.frameInterval = 0.07
            draft.minSpin = 1.2
            draft.win = moneySymbols.win
            draft.lose = moneySymbols.lose
            draft.spinning = moneySymbols.spinning
            // All-win flash celebrates the jackpot; the bust flash sinks the grid red on a
            // loss — deliberately shorter and quieter than the win.
            draft.finale = SlotTheme.SlotFinale(frames: 10, interval: 0.1)
            draft.bust = SlotTheme.SlotFinale(frames: 4, interval: 0.1)
        }
    }

    /// The money-slot faces, each row exactly 9 single-width columns.
    private static let moneySymbols: (win: SlotSymbol, lose: SlotSymbol, spinning: [SlotSymbol]) = (
        win: SlotSymbol(rows: [
            " ███████ ",
            " ▀▀▀▀▀██ ",
            "    ███  ",
            "   ███   ",
            "   ██    ",
        ]), // a chunky 7
        lose: SlotSymbol(rows: [
            "         ",
            " ███████ ",
            "         ",
            " ███████ ",
            "         ",
        ]), // a flat double-bar bust
        spinning: [
            SlotSymbol(rows: [
                "   ███   ",
                "  █ ▄ █  ",
                "  █ $ █  ",
                "  █ ▀ █  ",
                "   ███   ",
            ]), // dollar
            SlotSymbol(rows: [
                "  █████  ",
                " ██   ██ ",
                " ██ ¥ ██ ",
                " ██   ██ ",
                "  █████  ",
            ]), // yen
            SlotSymbol(rows: [
                "  ▄▄▄▄▄  ",
                " █ £   █ ",
                " █  £  █ ",
                " █   £ █ ",
                "  ▀▀▀▀▀  ",
            ]), // pound
            SlotSymbol(rows: [
                " ▓▓▓▓▓▓▓ ",
                " ▓ BAR ▓ ",
                " ▓▓▓▓▓▓▓ ",
                " ▓ BAR ▓ ",
                " ▓▓▓▓▓▓▓ ",
            ]), // bar
        ],
    )

    /// A flashy gold colorizer for the demo: solid truecolor gold, blinking on alternate
    /// frames. ANSI escapes add no display columns, so the reel grid stays aligned.
    private static let neonGold: SlotColorizer = { line, phase in
        let blink = (phase / 12).isMultiple(of: 2) ? "\u{1B}[5m" : ""
        return "\(blink)\u{1B}[1;38;2;255;215;0m\(line)\u{1B}[0m"
    }

    private static func emitLine(_ text: String) {
        FileHandle.standardOutput.write(Data("\(text)\n".utf8))
    }
}
