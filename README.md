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
   BUILD        TEST        LINT       DEPLOY   
```

…all four `7`s line up and the whole grid flashes — jackpot.

🌈 **A rainbow gradient scrolls** · ✨ **the winning grid flashes on a jackpot** ·
🔥 **every reel spins in parallel**. Dopamine, delivered.

---

## Why it feels good

- 🎡 **Spinning = visible progress.** Far more "alive" than a single spinner.
- ⚡️ **Every check is genuinely parallel.** Heavy network validation keeps the reels turning while you wait.
- 🎉 **All-pass flashes the winning grid.** Make the success land.
- 🤖 **Pipes and CI stay quiet.** Zero decoration, byte-stable output — it never misbehaves in production.
- 🪶 **Zero dependencies.** No logging or color library needed. SlotKit stands alone.

---

## Install

```swift
// Package.swift
.package(url: "https://github.com/Ryu0118/SlotKit", from: "0.2.0"),
```

```swift
.target(name: "YourApp", dependencies: ["SlotKit"]),
```

---

## Spin it in 30 seconds

```swift
import SlotKit

// A check = a reel. Each closure runs concurrently in the background.
// 🎰 Spin! Everything runs in parallel and stops as each check resolves.
let result = await SlotMachine.spin {
    SlotReel(label: "BUILD")  { compile() }                 // sync check
    SlotReel(label: "TEST")   { try await runTests() }      // long-running
    SlotReel(label: "LINT")   { try await lint() }
    if isMainBranch {
        SlotReel(label: "DEPLOY") { try await deploy() }    // only on main
    }
}

for outcome in result.outcomes {
    print("\(outcome.label ?? "reel"): \(outcome.passed ? "✅" : "❌")")
}
if result.allPassed { print("🎉 All reels passed!") }
```

A `work` closure returning `true` locks the reel on `7` (**win**); `false` or a
thrown error lands on `X` (**lose**). `spin` returns a `SlotResult` — just read
`outcomes` (each reel's result) and `allPassed` (did every reel win).

Labels are optional. Drop them — `SlotReel { spin() }` — and when every reel is
unlabeled the caption row disappears, leaving a plain slot machine (handy for a
spin-for-its-own-sake CLI rather than a named check runner).

---

## Going quiet (wiring up `--silent`)

`spin` **auto-detects** the terminal: it animates on a TTY, and falls back to a
plain result line on pipes, CI, or `NO_COLOR`. You can also force it — this is
how you wire it to a host `--silent` flag 👇

```swift
// `spin` also takes a plain `[SlotReel]` array if you'd rather build it yourself.
let reels: [SlotReel] = [
    SlotReel(label: "BUILD") { compile() },
    SlotReel(label: "TEST")  { try await runTests() },
]

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
    draft.finale        = SlotTheme.SlotFinale(frames: 8, interval: 0.12)  // all-win grid flash
    draft.bust          = SlotTheme.SlotFinale(frames: 6, interval: 0.18)  // orange↔red loss flash
}

await SlotMachine.spin(theme: theme) {
    SlotReel(label: "BUILD") { compile() }
    SlotReel(label: "TEST")  { try await runTests() }
}
```

The knobs:

| Knob | What it changes |
|------|-----------------|
| `cellWidth` / `cellHeight` | Reel window size (all symbols must share these dimensions) |
| `spinning` | The faces that flicker by while a reel spins |
| `win` / `lose` | The faces a reel locks on when it stops (pass/fail `spin`) |
| `symbols` / `jackpotIndex` | The faces reels land on, and which is the jackpot (symbol `spinSymbols`) |
| `colorize` | Coloring `(line, phase) -> String`. `.rainbow` / `.plain` / your own |
| `frameInterval` | Spin speed (interval between frames) |
| `minSpin` | Minimum spin time (so a reel doesn't finish in a dull instant) |
| `finale` | The all-win flash: blink the winning grid (flash count, interval); `nil` = no flash |
| `bust` | The loss flash: the final grid pulses orange ↔ red; `nil` = no loss animation |

> A custom `colorize` receives one laid-out line plus the animation phase.
> **Don't change the display width** — doing so misaligns the reel grid. Color only.

With nothing specified you get `SlotTheme.default` (the 10×5 arcade faces, rainbow
gradient, 90 ms cadence, 1 s spin, and the all-win grid flash) — exactly what you
saw above.

Want the arcade look but a tweak or two? Derive from any theme with `with` —
it inherits every field you don't touch and re-validates the result, so a change
that breaks the symbol dimensions throws `SlotThemeError` instead of misaligning.

```swift
// Same default look, just faster.
let snappy = try SlotTheme.default.with { draft in
    draft.minSpin       = 0
    draft.frameInterval = 0.02
}
```

---

## Real slot machine: matching symbols 🍒

The `spin` above is **pass/fail** — every reel lands on `win` or `lose`. For an
actual slot machine, where each reel stops on one of *several* faces and you win
by **lining them up**, reach for `spinSymbols`.

Give the theme a set of `symbols` to land on (and which index is the jackpot),
then return a landed index from each reel:

```swift
let theme = try SlotTheme.default.with { draft in
    draft.symbols      = [seven, cherry, bar, bell]   // the faces reels can stop on
    draft.jackpotIndex = 0                             // index 0 (seven) is the top line
}

let result = await SlotMachine.spinSymbols(theme: theme) {
    SymbolReel(label: "1") { draw() }   // each returns an index into `theme.symbols`
    SymbolReel(label: "2") { draw() }
    SymbolReel(label: "3") { draw() }
}

if result.isJackpot {       // every reel on `jackpotIndex` → 777
    print("🎰 JACKPOT!")
} else if result.allSame {   // every reel on the same (non-jackpot) symbol → a win line
    print("🍒 Winner!")
} else {
    print("…spin again.")    // mixed line → no win
}
```

A `SymbolReel`'s closure returns an `Int` — the index into `theme.symbols` the
reel lands on. SlotKit only animates the reveal; **you supply the draw**, so the
odds (how rare a `777` is) live entirely in your code. `spinSymbols` returns a
`SymbolSpinResult`: read `outcomes` (each reel's `landedIndex`), `allSame` (every
reel matched), and `isJackpot` (every reel on `jackpotIndex`).

Like `spin`, `spinSymbols` takes a plain `[SymbolReel]` array and a `plain:` flag,
and stays byte-stable on pipes / CI. The pass/fail `spin` is untouched — both live
side by side.

---

## See it move first 👀

```bash
swift run slotkit-demo            # 🎰 all win → the winning grid flashes
swift run slotkit-demo --fail     # 💥 one reel loses → orange↔red bust flash, no jackpot
swift run slotkit-demo --custom   # 💰 a money-slot theme: gold neon + all-win flash
swift run slotkit-demo --bare     # 🎰 unlabeled reels — no caption row, just the slot
swift run slotkit-demo | cat      # 🤐 piped = plain result only
```

A picture's worth a thousand words. Run `swift run slotkit-demo` in your terminal
and watch the reels spin.

---

## License

SlotKit is released under the MIT License. See [LICENSE](LICENSE) for details.
