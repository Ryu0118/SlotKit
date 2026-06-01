# SlotKit

An ASCII-art **slot machine** for the terminal that dramatizes a set of parallel
async checks. Each check is a spinning reel; when it resolves, the reel locks on a
win or lose face. When every reel wins, an optional jackpot flourish fires.

Built for CLIs. Fully self-contained — no logging framework, no color library.
Animation is shown only on an interactive TTY; piped/CI/`NO_COLOR` output falls back
to plain, deterministic results.

## Install

```swift
.package(url: "https://github.com/Ryu0118/SlotKit", from: "0.1.0"),
```

```swift
.target(name: "YourApp", dependencies: ["SlotKit"]),
```

## Quick start

```swift
import SlotKit

let reels = [
    SlotReel(label: "YAML")  { validateYAML() },
    SlotReel(label: "AUTH")  { try await checkAuth() },     // network check
    SlotReel(label: "DRIFT") { try await checkDrift() },
]

let result = await SlotMachine.spin(reels)   // spins all reels concurrently

for outcome in result.outcomes {
    print("\(outcome.label): \(outcome.passed ? "ok" : "failed")")
}
if result.allPassed { print("All checks passed.") }
```

Each reel's `work` runs **immediately and in parallel**; its reel keeps spinning until
the closure returns. `true` locks the reel on the win face, `false` or a thrown error
on the lose face. `spin` returns a `SlotResult` — inspect `outcomes` and `allPassed`.

## Plain / silent output

`spin` auto-detects the terminal. Force it with the `plain` argument — this is the
bridge to a host `--silent` flag:

```swift
await SlotMachine.spin(reels, plain: isSilent)   // true → no animation, just results
await SlotMachine.spin(reels, plain: nil)        // nil (default) → auto-detect TTY
```

When plain, nothing is drawn: the checks still run and results are returned, so the
caller prints its own lines and output stays byte-stable.

## Customization

Everything visual lives in a `SlotTheme`, built through a validated factory. Symbol
dimensions are checked up front — every symbol must be exactly `cellWidth × cellHeight`,
or `make` throws `SlotThemeError` instead of clipping silently.

```swift
let theme = try SlotTheme.make { draft in
    draft.cellWidth = 7
    draft.cellHeight = 3
    draft.win  = SlotSymbol(rows: ["  ╱    ", " ╱     ", "╲╱     "])
    draft.lose = SlotSymbol(rows: ["       ", "═══════", "       "])
    draft.spinning = [
        SlotSymbol(rows: ["  ▄▄▄  ", " █████ ", "  ▀▀▀  "]),
        SlotSymbol(rows: ["  ◇◇◇  ", " ◇◇◇◇◇ ", "  ◇◇◇  "]),
    ]
    draft.colorize = SlotColorizers.rainbow          // or .plain, or your own
    draft.frameInterval = 0.09                        // seconds per frame
    draft.minSpin = 1.0                               // min spin before a reel locks
    draft.finale = SlotTheme.SlotFinale(text: " ✦ ALL GREEN ✦ ")
}

await SlotMachine.spin(reels, theme: theme)
```

Customization axes:

| Field           | What it controls                                            |
|-----------------|-------------------------------------------------------------|
| `cellWidth/Height` | reel window geometry (all symbols must match)            |
| `spinning`      | faces cycled while a reel spins                              |
| `win` / `lose`  | faces a reel locks on                                       |
| `colorize`      | `(line, phase) -> String`; `.rainbow`, `.plain`, or custom  |
| `frameInterval` | animation cadence                                           |
| `minSpin`       | minimum spin time before a reel may lock                    |
| `finale`        | optional all-win flourish (text, frames, interval)          |

A custom `colorize` receives each laid-out line plus the animation phase and must
preserve the line's display width so the reel grid stays aligned.

`SlotTheme.default` is the built-in 10×5 arcade theme (rainbow gradient, 90 ms frames,
1 s spin, flashing `JACKPOT`).

## Demo

```bash
swift run slotkit-demo            # animated, all win → jackpot
swift run slotkit-demo --fail     # one reel loses, no jackpot
swift run slotkit-demo --custom   # a custom 7×3 theme
swift run slotkit-demo | cat      # plain, piped output
```

## License

MIT
