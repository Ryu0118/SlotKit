# 🎰 SlotKit

> **Kill the boring `Checking… ✓`.** A Swift library that turns your CLI's
> checks into a **clattering ASCII slot machine** — arcade lights and all.

One check = one reel. While the work runs the reel **spins**, and the instant it
resolves it **slams to a stop** on `7` (pass) or `X` (fail). Line up all `7`s and…

```
╔══════════╗╔══════════╗╔══════════╗╔══════════╗
║ ███████  ║║ ███████  ║║ ███████  ║║ ███████  ║
║ ▀▀▀▀██   ║║ ▀▀▀▀██   ║║ ▀▀▀▀██   ║║ ▀▀▀▀██   ║
║    ██    ║║    ██    ║║    ██    ║║    ██    ║
║   ██     ║║   ██     ║║   ██     ║║   ██     ║
║   ██     ║║   ██     ║║   ██     ║║   ██     ║
╚══════════╝╚══════════╝╚══════════╝╚══════════╝
   YAML        PROP        AUTH        DRIFT

       ★ ★ ★   J A C K P O T   ★ ★ ★
```

🌈 **A rainbow gradient scrolls** · ✨ **`JACKPOT` flashes** ·
🔥 **every reel spins in parallel**. Dopamine, delivered.

---

## Why it feels good

- 🎡 **Spinning = visible progress.** Far more "alive" than a single spinner.
- ⚡️ **Every check is genuinely parallel.** Heavy network validation keeps the reels turning while you wait.
- 🎉 **All-pass fires a JACKPOT.** Make the success land.
- 🤖 **Pipes and CI stay quiet.** Zero decoration, byte-stable output — it never misbehaves in production.
- 🪶 **Zero dependencies.** No logging or color library needed. SlotKit stands alone.

---

## Install

```swift
// Package.swift
.package(url: "https://github.com/Ryu0118/SlotKit", from: "0.1.0"),
```

```swift
.target(name: "YourApp", dependencies: ["SlotKit"]),
```

---

## Spin it in 30 seconds

```swift
import SlotKit

// A check = a reel. Each closure runs concurrently in the background.
let reels = [
    SlotReel(label: "YAML")  { validateYAML() },          // sync check
    SlotReel(label: "AUTH")  { try await checkAuth() },   // network
    SlotReel(label: "DRIFT") { try await checkDrift() },
]

// 🎰 Spin! Everything runs in parallel and stops as each check resolves.
let result = await SlotMachine.spin(reels)

for outcome in result.outcomes {
    print("\(outcome.label): \(outcome.passed ? "✅" : "❌")")
}
if result.allPassed { print("🎉 All reels passed!") }
```

A `work` closure returning `true` locks the reel on `7` (**win**); `false` or a
thrown error lands on `X` (**lose**). `spin` returns a `SlotResult` — just read
`outcomes` (each reel's result) and `allPassed` (did every reel win).

---

## Going quiet (wiring up `--silent`)

`spin` **auto-detects** the terminal: it animates on a TTY, and falls back to a
plain result line on pipes, CI, or `NO_COLOR`. You can also force it — this is
how you wire it to a host `--silent` flag 👇

```swift
await SlotMachine.spin(reels, plain: isSilent)  // true → no animation, result only
await SlotMachine.spin(reels, plain: nil)       // nil (default) → auto-detect the terminal
```

When `plain` is in effect **nothing is drawn**. The checks still run and a result
is still returned, so the caller can print its own plain lines. Output stays
byte-stable — safe for tests and CI.

---

## Make it yours 🎨

Look and timing all live in `SlotTheme`. Building one through `make` **validates
the symbol dimensions up front** — if any symbol is off by even one cell from
`cellWidth × cellHeight`, it throws `SlotThemeError` instead of silently clipping
at render time. No surprises.

```swift
let theme = try SlotTheme.make { draft in
    draft.cellWidth  = 7
    draft.cellHeight = 3
    draft.win  = SlotSymbol(rows: ["  ╱    ", " ╱     ", "╲╱     "])  // the win face
    draft.lose = SlotSymbol(rows: ["       ", "═══════", "       "])  // the lose face
    draft.spinning = [                                                // the spinning faces
        SlotSymbol(rows: ["  ▄▄▄  ", " █████ ", "  ▀▀▀  "]),
        SlotSymbol(rows: ["  ◇◇◇  ", " ◇◇◇◇◇ ", "  ◇◇◇  "]),
    ]
    draft.colorize      = SlotColorizers.rainbow   // .rainbow / .plain / your own
    draft.frameInterval = 0.09                     // seconds per frame (speed)
    draft.minSpin       = 1.0                      // minimum spin time (avoid finishing too fast)
    draft.finale        = SlotTheme.SlotFinale(text: " ✦ ALL GREEN ✦ ")  // all-win flourish
}

await SlotMachine.spin(reels, theme: theme)
```

The knobs:

| Knob | What it changes |
|------|-----------------|
| `cellWidth` / `cellHeight` | Reel window size (all symbols must share these dimensions) |
| `spinning` | The faces that flicker by while a reel spins |
| `win` / `lose` | The faces a reel locks on when it stops |
| `colorize` | Coloring `(line, phase) -> String`. `.rainbow` / `.plain` / your own |
| `frameInterval` | Spin speed (interval between frames) |
| `minSpin` | Minimum spin time (so a reel doesn't finish in a dull instant) |
| `finale` | The all-win flourish (text, flash count, interval) |

> A custom `colorize` receives one laid-out line plus the animation phase.
> **Don't change the display width** — doing so misaligns the reel grid. Color only.

With nothing specified you get `SlotTheme.default` (the 10×5 arcade faces, rainbow
gradient, 90 ms cadence, 1 s spin, and the flashing `JACKPOT`) — exactly what you
saw above.

---

## See it move first 👀

```bash
swift run slotkit-demo            # 🎰 all win → JACKPOT
swift run slotkit-demo --fail     # 💥 one reel loses → no jackpot
swift run slotkit-demo --custom   # 🎨 a custom 7×3 theme
swift run slotkit-demo | cat      # 🤐 piped = plain result only
```

A picture's worth a thousand words. Run `swift run slotkit-demo` in your terminal
and watch the reels spin.

---

## License

SlotKit is released under the MIT License. See [LICENSE](LICENSE) for details.
