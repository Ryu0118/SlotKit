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
    static func main() async {
        let arguments = Set(CommandLine.arguments.dropFirst())
        let forceFail = arguments.contains("--fail")
        let custom = arguments.contains("--custom")

        let theme: SlotTheme = custom ? customTheme() : .default

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

    private static func customTheme() -> SlotTheme {
        // A minimal custom theme: 7×3 cells, two spinning faces, a slash vs a dash.
        guard let theme = try? SlotTheme.make({ draft in
            draft.cellWidth = 7
            draft.cellHeight = 3
            draft.win = SlotSymbol(rows: ["  ╱    ", " ╱     ", "╲╱     "])
            draft.lose = SlotSymbol(rows: ["       ", "═══════", "       "])
            draft.spinning = [
                SlotSymbol(rows: ["  ▄▄▄  ", " █████ ", "  ▀▀▀  "]),
                SlotSymbol(rows: ["  ◇◇◇  ", " ◇◇◇◇◇ ", "  ◇◇◇  "]),
            ]
            draft.finale = SlotTheme.SlotFinale(text: " ✦ ALL GREEN ✦ ")
        }) else {
            fatalError("custom demo theme has inconsistent symbol dimensions")
        }
        return theme
    }

    private static func emitLine(_ text: String) {
        FileHandle.standardOutput.write(Data("\(text)\n".utf8))
    }
}
