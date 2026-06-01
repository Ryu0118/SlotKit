# SlotKit

A self-contained, customizable ASCII-art **slot machine** for the terminal that
dramatizes a set of parallel async checks. One library module, plus a demo executable.

## Architecture

```
SlotKit (library)   ← slotkit-demo (executable, for visual testing only)
```

Single module, no external dependencies. The public surface is small:

- `SlotMachine.spin(reels:theme:plain:)` — the entry point; spins reels concurrently.
- `SlotReel` / `SlotResult` / `SlotOutcome` — the check + its result.
- `SlotTheme` (+ `SlotSymbol`, `SlotColorizer`) — fully customizable visuals/timing.

Internally:

- `SlotRenderer` — **pure**, side-effect-free frame layout. This is the test surface.
- `SlotMachine` — the async driver: spawns per-reel tasks, animates, emits via `FileHandle`.
- `Terminal` — built-in TTY / `NO_COLOR` detection.

Keep the pure/impure split: layout logic stays in `SlotRenderer` (testable); only
`SlotMachine` touches the terminal.

## Development

```bash
make setup      # nest bootstrap (lint tools) + git hooks + mise install
make build      # swift build
make test       # swift test
make format     # swiftformat (apply)
make lint       # swiftlint --strict
make my-swift-lint  # my-swift-linter (AST rules)
make periphery  # unused/redundant-public scan
make docsync    # doc/source sync check
make check      # format-lint + lint + my-swift-lint + test + docsync
```

The toolchain is pinned via `nestfile.yaml` and resolved into `.nest/bin/` by
`scripts/nest.sh`. `gitleaks` comes from `mise`.

## Conventions

- Swift 6.2, macOS 15+. Strict concurrency.
- Follow `.swiftlint.yml` strictly — **0 violations**. `--strict` is enforced by hooks and CI.
- `swiftlint:disable` is **banned**. Fix the underlying issue.
- **No `print` / `fputs`.** Output goes through `FileHandle.standardOutput` (the library
  has no logging dependency by design).
- `public` only for the genuine library surface; `public` declarations need doc comments
  (`missing_docs`). Internal helpers stay non-public.
- No file-scope `func` in library code (`no-top-level-function`) — use a type/extension
  or a namespace `enum`. (The demo's `main.swift` is exempt by nature.)

## Design Rules

- The library must stay self-contained: no logging framework, no color library.
- Output must be deterministic: animation only on an interactive TTY; plain (byte-stable)
  otherwise. `spin(plain:)` lets a host force plain to honor a `--silent`-style flag.
- Custom themes are validated up front (`SlotTheme.make`): every symbol must match the
  theme's `cellWidth × cellHeight`, or construction throws.

## Hooks & Gates

- **pre-commit**: gitleaks + swiftformat + swiftlint --strict + my-swift-linter + docsync.
- **pre-push**: periphery scan (blocks on redundant public).
- **Claude / Codex** PostToolUse hooks run the same lint on every edit.

Activate locally with `make hooks` (or `make setup`).
