/// The complete visual + timing configuration for a slot machine.
///
/// A theme fixes the reel geometry (`cellWidth` × `cellHeight`), the faces shown while
/// spinning and when a reel resolves to win/lose, the colorizer, the frame cadence, and
/// the minimum spin time. Build one with ``SlotTheme/make(_:)`` so symbol dimensions are
/// validated, or use ``SlotTheme/default`` for the built-in arcade look.
public struct SlotTheme: Sendable {
    /// Inner width of a reel window, in display columns.
    public let cellWidth: Int
    /// Number of art rows inside a reel window.
    public let cellHeight: Int
    /// Faces cycled through while a reel is still spinning.
    public let spinning: [SlotSymbol]
    /// Face a reel locks on when its check passes.
    public let win: SlotSymbol
    /// Face a reel locks on when its check fails.
    public let lose: SlotSymbol
    /// Colors a laid-out line for the given animation phase.
    public let colorize: SlotColorizer
    /// Seconds between animation frames while spinning.
    public let frameInterval: Double
    /// Minimum seconds a reel keeps spinning before it may lock.
    public let minSpin: Double
    /// Optional flourish played when every reel wins (the winning grid flashes).
    public let finale: SlotFinale?
    /// Optional restrained flash played when at least one reel loses — a red sink on the
    /// final grid, deliberately milder than `finale`. `nil` means the grid just settles.
    public let bust: SlotFinale?
    /// The faces a reel may land on in the symbol-matching mode (``SlotMachine/spinSymbols(_:theme:plain:)``).
    /// Empty in the win/lose (pass/fail) mode, which lands only on ``win`` / ``lose``.
    public let symbols: [SlotSymbol]
    /// The index into ``symbols`` of the top-paying face (the jackpot). `nil` when no symbol
    /// is singled out as the jackpot, or in win/lose mode. Used only to flag a jackpot win.
    public let jackpotIndex: Int?
    /// Whether in-flight reels scroll their faces vertically (a real reel sliding past a
    /// window) instead of swapping the whole face each frame. Grid path only; default `false`
    /// keeps the original frame-swap look. Landing, layout, and odds are unchanged either way.
    public let scrollSpin: Bool
    /// Per-column spinning strips, for a grid where each reel scrolls a different sequence of
    /// faces. When non-empty, column `i` scrolls `spinningStrips[i % spinningStrips.count]`
    /// instead of the shared ``spinning``; this is how a real machine weights a symbol
    /// differently on each reel. Empty (the default) means every column shares ``spinning``.
    public let spinningStrips: [[SlotSymbol]]

    /// A grid flash: the on-screen grid is pulsed in place for `frames` beats — the win
    /// `finale` toggles bright ↔ dim to celebrate a jackpot, the `bust` flash sinks the grid
    /// red to mark a loss. A `nil` flash on the theme means no animation (the grid settles).
    public struct SlotFinale: Sendable {
        /// Number of flash beats (each toggles the grid between its live look and the off look).
        public let frames: Int
        /// Seconds between beats.
        public let interval: Double

        /// Creates a grid-flash flourish.
        public init(frames: Int = 8, interval: Double = 0.12) {
            self.frames = frames
            self.interval = interval
        }
    }

    /// Memberwise initializer used by validated factories and the built-in theme.
    /// External callers should go through ``SlotTheme/make(_:)`` so dimensions are checked.
    init(
        cellWidth: Int,
        cellHeight: Int,
        spinning: [SlotSymbol],
        win: SlotSymbol,
        lose: SlotSymbol,
        colorize: @escaping SlotColorizer,
        frameInterval: Double,
        minSpin: Double,
        finale: SlotFinale?,
        bust: SlotFinale? = nil,
        symbols: [SlotSymbol] = [],
        jackpotIndex: Int? = nil,
        scrollSpin: Bool = false,
        spinningStrips: [[SlotSymbol]] = [],
    ) {
        self.cellWidth = cellWidth
        self.cellHeight = cellHeight
        self.spinning = spinning
        self.win = win
        self.lose = lose
        self.colorize = colorize
        self.frameInterval = frameInterval
        self.minSpin = minSpin
        self.finale = finale
        self.bust = bust
        self.symbols = symbols
        self.jackpotIndex = jackpotIndex
        self.scrollSpin = scrollSpin
        self.spinningStrips = spinningStrips
    }

    /// A draft theme passed to ``SlotTheme/make(_:)``; mutate its fields then build.
    public struct Draft {
        /// Inner width of a reel window, in display columns.
        public var cellWidth = 9
        /// Number of art rows inside a reel window.
        public var cellHeight = 5
        /// Faces cycled through while spinning.
        public var spinning: [SlotSymbol] = []
        /// Face shown when a reel passes.
        public var win = SlotSymbol(rows: [])
        /// Face shown when a reel fails.
        public var lose = SlotSymbol(rows: [])
        /// Line colorizer; defaults to the rainbow gradient.
        public var colorize: SlotColorizer = SlotColorizers.rainbow
        /// Seconds between spin frames.
        public var frameInterval = 0.09
        /// Minimum seconds a reel spins before locking.
        public var minSpin = 1.0
        /// Optional all-win flourish.
        public var finale: SlotFinale?
        /// Optional restrained loss flash (a red sink). `nil` = no loss animation.
        public var bust: SlotFinale?
        /// Faces a reel may land on in symbol-matching mode. Empty = win/lose mode only.
        public var symbols: [SlotSymbol] = []
        /// Index into ``symbols`` of the jackpot face. `nil` = no jackpot singled out.
        public var jackpotIndex: Int?
        /// Whether in-flight reels scroll vertically (grid path). Default `false`.
        public var scrollSpin = false
        /// Per-column spinning strips (grid path). Leave empty to share ``spinning`` across
        /// every column; set one strip per column to weight faces differently per reel.
        /// Element count need not match the column count — columns wrap via modulo.
        public var spinningStrips: [[SlotSymbol]] = []

        /// An empty draft to fill in from scratch.
        init() {}

        /// Seeds a draft with an existing theme's fields, so a derived theme need only
        /// override the few it wants to change. See ``SlotTheme/with(_:)``.
        init(from theme: SlotTheme) {
            cellWidth = theme.cellWidth
            cellHeight = theme.cellHeight
            spinning = theme.spinning
            win = theme.win
            lose = theme.lose
            colorize = theme.colorize
            frameInterval = theme.frameInterval
            minSpin = theme.minSpin
            finale = theme.finale
            bust = theme.bust
            symbols = theme.symbols
            jackpotIndex = theme.jackpotIndex
            scrollSpin = theme.scrollSpin
            spinningStrips = theme.spinningStrips
        }
    }

    /// Builds a validated theme from scratch. Every symbol (spinning, win, lose) must have
    /// exactly `cellHeight` rows, each `cellWidth` characters wide; otherwise this throws
    /// ``SlotThemeError`` rather than letting reels clip or misalign at render time.
    public static func make(_ configure: (inout Draft) -> Void) throws -> SlotTheme {
        var draft = Draft()
        configure(&draft)
        return try build(from: draft)
    }

    /// Derives a new theme from this one, applying `configure` to a draft pre-filled with
    /// this theme's fields — so you can tweak a few knobs of ``SlotTheme/default`` (or any
    /// theme) without rebuilding it. The result is validated like ``SlotTheme/make(_:)``,
    /// so a change that breaks the symbol dimensions (e.g. `cellWidth` without resizing the
    /// art) throws ``SlotThemeError`` instead of misaligning silently.
    ///
    /// ```swift
    /// let snappy = try SlotTheme.default.with { $0.minSpin = 0; $0.frameInterval = 0.02 }
    /// ```
    public func with(_ configure: (inout Draft) -> Void) throws -> SlotTheme {
        var draft = Draft(from: self)
        configure(&draft)
        return try SlotTheme.build(from: draft)
    }

    /// The single validating build step shared by ``make(_:)`` and ``with(_:)``.
    private static func build(from draft: Draft) throws -> SlotTheme {
        try validate(draft.win, label: "win", width: draft.cellWidth, height: draft.cellHeight)
        try validate(draft.lose, label: "lose", width: draft.cellWidth, height: draft.cellHeight)
        guard !draft.spinning.isEmpty else { throw SlotThemeError.noSpinningSymbols }
        for (index, symbol) in draft.spinning.enumerated() {
            try validate(symbol, label: "spinning[\(index)]", width: draft.cellWidth, height: draft.cellHeight)
        }
        for (index, symbol) in draft.symbols.enumerated() {
            try validate(symbol, label: "symbols[\(index)]", width: draft.cellWidth, height: draft.cellHeight)
        }
        if let jackpotIndex = draft.jackpotIndex, !draft.symbols.indices.contains(jackpotIndex) {
            throw SlotThemeError.jackpotIndexOutOfRange(index: jackpotIndex, symbolCount: draft.symbols.count)
        }
        try validateSpinningStrips(draft)
        return SlotTheme(
            cellWidth: draft.cellWidth,
            cellHeight: draft.cellHeight,
            spinning: draft.spinning,
            win: draft.win,
            lose: draft.lose,
            colorize: draft.colorize,
            frameInterval: draft.frameInterval,
            minSpin: draft.minSpin,
            finale: draft.finale,
            bust: draft.bust,
            symbols: draft.symbols,
            jackpotIndex: draft.jackpotIndex,
            scrollSpin: draft.scrollSpin,
            spinningStrips: draft.spinningStrips,
        )
    }

    /// Validates the per-column strips: every face must fit the cell, and no strip may be empty
    /// (an empty strip would divide by zero when the renderer wraps the scroll position). An
    /// empty `spinningStrips` is fine — it means every column shares ``spinning``.
    private static func validateSpinningStrips(_ draft: Draft) throws {
        for (column, strip) in draft.spinningStrips.enumerated() {
            guard !strip.isEmpty else { throw SlotThemeError.emptySpinningStrip(column: column) }
            for (index, symbol) in strip.enumerated() {
                let label = "spinningStrips[\(column)][\(index)]"
                try validate(symbol, label: label, width: draft.cellWidth, height: draft.cellHeight)
            }
        }
    }

    private static func validate(_ symbol: SlotSymbol, label: String, width: Int, height: Int) throws {
        guard symbol.rows.count == height else {
            throw SlotThemeError.wrongRowCount(symbol: label, expected: height, found: symbol.rows.count)
        }
        for (index, row) in symbol.rows.enumerated() where row.count != width {
            throw SlotThemeError.wrongRowWidth(symbol: label, row: index, expected: width, found: row.count)
        }
    }
}

/// Why a ``SlotTheme`` failed validation.
public enum SlotThemeError: Error, Equatable {
    /// A symbol has the wrong number of rows for the theme's `cellHeight`.
    case wrongRowCount(symbol: String, expected: Int, found: Int)
    /// A symbol row is not `cellWidth` characters wide.
    case wrongRowWidth(symbol: String, row: Int, expected: Int, found: Int)
    /// The theme has no spinning symbols to cycle through.
    case noSpinningSymbols
    /// `jackpotIndex` does not point at a valid entry in `symbols`.
    case jackpotIndexOutOfRange(index: Int, symbolCount: Int)
    /// A per-column spinning strip at `column` is empty (it must list at least one face).
    case emptySpinningStrip(column: Int)
}

extension SlotTheme {
    /// The strip an in-flight column scrolls through: `spinningStrips[column % count]` when
    /// per-column strips are set, otherwise the shared ``spinning``. The modulo wrap lets a
    /// short `spinningStrips` cover any column count. Internal — the resolution rule is an
    /// implementation detail that the renderer and the skill-stop both rely on.
    func strip(forColumn column: Int) -> [SlotSymbol] {
        spinningStrips.isEmpty ? spinning : spinningStrips[column % spinningStrips.count]
    }
}
