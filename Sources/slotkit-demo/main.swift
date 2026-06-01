import Foundation
import SlotKit

// A tiny demo so the animation can be watched by eye. Each "check" just sleeps a
// random-ish amount and returns a fixed result, so reels resolve at staggered times.
//
// Run:  swift run slotkit-demo            (animated, all win → jackpot)
//       swift run slotkit-demo --fail     (one reel loses, no jackpot)
//       swift run slotkit-demo | cat      (plain, piped output)
//       swift run slotkit-demo --custom   (a custom 2-symbol theme)

let arguments = Set(CommandLine.arguments.dropFirst())
let forceFail = arguments.contains("--fail")
let custom = arguments.contains("--custom")

func delayedCheck(_ label: String, passes: Bool, milliseconds: Int) -> SlotReel {
    SlotReel(label: label) {
        try? await Task.sleep(for: .milliseconds(milliseconds))
        return passes
    }
}

let reels = [
    delayedCheck("YAML", passes: true, milliseconds: 400),
    delayedCheck("PROP", passes: true, milliseconds: 900),
    delayedCheck("AUTH", passes: !forceFail, milliseconds: 1500),
    delayedCheck("DRIFT", passes: true, milliseconds: 2100),
]

let theme: SlotTheme = if custom {
    // A minimal custom theme: 7×3 cells, two spinning faces, a green check vs red dash.
    // swiftlint:disable:next force_try
    try! SlotTheme.make { draft in
        draft.cellWidth = 7
        draft.cellHeight = 3
        draft.win = SlotSymbol(rows: ["  ╱    ", " ╱     ", "╲╱     "])
        draft.lose = SlotSymbol(rows: ["       ", "═══════", "       "])
        draft.spinning = [
            SlotSymbol(rows: ["  ▄▄▄  ", " █████ ", "  ▀▀▀  "]),
            SlotSymbol(rows: ["  ◇◇◇  ", " ◇◇◇◇◇ ", "  ◇◇◇  "]),
        ]
        draft.finale = SlotTheme.SlotFinale(text: " ✦ ALL GREEN ✦ ")
    }
} else {
    .default
}

let result = await SlotMachine.spin(reels, theme: theme)

/// Emit plain result lines afterwards (the host app's job in real use).
func emitLine(_ text: String) {
    FileHandle.standardOutput.write(Data("\(text)\n".utf8))
}

for outcome in result.outcomes {
    emitLine("\(outcome.label): \(outcome.passed ? "pass" : "fail")")
}

emitLine(result.allPassed ? "All reels passed." : "Some reels failed.")
