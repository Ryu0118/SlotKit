# 🎰 SlotKit

> **退屈な `Checking… ✓` にサヨナラ。** あなたの CLI のチェックを、
> パチンコ屋のフィーバーみたいに **ガチャガチャ回る ASCII スロット**に変える Swift ライブラリ。

チェック1個 = リール1本。処理が走ってる間リールは **ぐるんぐるん回り**、終わった瞬間に
`7`（成功）か `X`（失敗）で **ガチン！と止まる**。ぜんぶ `7` で揃ったら…

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

🌈 **虹色グラデーションが流れる** ／ ✨ **`JACKPOT` がチカチカ点滅** ／
🔥 **全リール並列でぶん回る**。脳汁、出ます。

---

## なんで気持ちええのか

- 🎡 **回ってる = 進捗が見える。** スピナー1個より圧倒的に「動いてる感」。
- ⚡️ **全チェックが本当に並列。** 重いネットワーク検証も、待ってる間ずっとリールが回る。
- 🎉 **全部通ると JACKPOT 演出。** 成功体験を爆発させる。やめられん。
- 🤖 **でもパイプ／CI ではちゃんと地味になる。** 装飾ゼロ・byte 安定。本番で暴れない。
- 🪶 **依存ゼロ。** ログライブラリも色ライブラリも要らん。SlotKit 単体で動く。

---

## 入れる

```swift
// Package.swift
.package(url: "https://github.com/Ryu0118/SlotKit", from: "0.1.0"),
```

```swift
.target(name: "YourApp", dependencies: ["SlotKit"]),
```

---

## 30秒で回す

```swift
import SlotKit

// チェック = リール。各クロージャが裏で並列に走る。
let reels = [
    SlotReel(label: "YAML")  { validateYAML() },          // 同期チェック
    SlotReel(label: "AUTH")  { try await checkAuth() },   // ネットワーク
    SlotReel(label: "DRIFT") { try await checkDrift() },
]

// 🎰 回す！ ぜんぶ並列で走って、終わった順にガチンと止まる。
let result = await SlotMachine.spin(reels)

for outcome in result.outcomes {
    print("\(outcome.label): \(outcome.passed ? "✅" : "❌")")
}
if result.allPassed { print("🎉 全部通った！") }
```

`work` が `true` を返したら **`7` で当たり**、`false` か throw したら **`X` で外れ**。
`spin` は `SlotResult` を返すから、`outcomes`（各リールの結果）と `allPassed`（全勝か）を見るだけ。

---

## 静かにしたい時（`--silent` と繋ぐ）

`spin` は端末を**自動判定**する。ターミナルなら回る、パイプ／CI／`NO_COLOR` なら地味に結果だけ。
明示的に強制もできる ── ホストの `--silent` フラグと繋ぐのはコレ👇

```swift
await SlotMachine.spin(reels, plain: isSilent)  // true → 演出なし、結果だけ
await SlotMachine.spin(reels, plain: nil)       // nil（既定）→ 端末を自動判定
```

`plain` の時は**一切描画しない**。チェックは走るし結果も返るから、呼び出し側が自分で
プレーンな行を出せばOK。出力は byte 単位で安定 = テストもCIも安心。

---

## 自分好みにカスタムする 🎨

見た目とタイミングは全部 `SlotTheme` に入ってる。`make` で組むと
**シンボルの寸法を最初にチェック**してくれる ── どれか1個でも `cellWidth × cellHeight`
からズレてたら、黙ってクリップせず `SlotThemeError` を投げる。事故らない。

```swift
let theme = try SlotTheme.make { draft in
    draft.cellWidth  = 7
    draft.cellHeight = 3
    draft.win  = SlotSymbol(rows: ["  ╱    ", " ╱     ", "╲╱     "])  // 当たりの顔
    draft.lose = SlotSymbol(rows: ["       ", "═══════", "       "])  // 外れの顔
    draft.spinning = [                                                // 回転中の顔たち
        SlotSymbol(rows: ["  ▄▄▄  ", " █████ ", "  ▀▀▀  "]),
        SlotSymbol(rows: ["  ◇◇◇  ", " ◇◇◇◇◇ ", "  ◇◇◇  "]),
    ]
    draft.colorize      = SlotColorizers.rainbow   // .rainbow / .plain / 自作
    draft.frameInterval = 0.09                     // 1フレームの秒数（速さ）
    draft.minSpin       = 1.0                      // 最低何秒は回すか（早すぎ防止）
    draft.finale        = SlotTheme.SlotFinale(text: " ✦ ALL GREEN ✦ ")  // 全勝演出
}

await SlotMachine.spin(reels, theme: theme)
```

いじれるツマミ:

| ツマミ | 何が変わる |
|--------|------------|
| `cellWidth` / `cellHeight` | リール窓の大きさ（全シンボル同じ寸法に揃える） |
| `spinning` | 回転中にパラパラ切り替わる顔たち |
| `win` / `lose` | 止まった時の当たり／外れの顔 |
| `colorize` | 色付け `(line, phase) -> String`。`.rainbow`／`.plain`／自作 |
| `frameInterval` | 回転の速さ（フレーム間隔） |
| `minSpin` | 最低スピン時間（一瞬で終わってつまらん、を防ぐ） |
| `finale` | 全勝した時のフィーバー演出（文字・点滅回数・間隔） |

> 自作 `colorize` は「組み上がった1行 + アニメの phase」を受け取る。
> **表示幅は変えるな** ── 変えるとリールの格子がズレる。色だけ盛れ。

何も指定しなければ `SlotTheme.default`（10×5 のアーケード顔・虹グラデ・90ms・1秒スピン・
点滅 `JACKPOT`）が使われる。今あなたが上で見たアレ。

---

## まず動かして見てみ 👀

```bash
swift run slotkit-demo            # 🎰 全部当たり → JACKPOT
swift run slotkit-demo --fail     # 💥 1個外れる → ジャックポットなし
swift run slotkit-demo --custom   # 🎨 自作 7×3 テーマ
swift run slotkit-demo | cat      # 🤐 パイプ = 地味な結果だけ
```

百聞は一見にしかず。ターミナルで `swift run slotkit-demo` 打って、回るとこ見てくれ。

---

## License

SlotKit is released under the MIT License. See [LICENSE](LICENSE) for details.
