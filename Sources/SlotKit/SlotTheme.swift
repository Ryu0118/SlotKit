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
    /// Optional flourish played when every reel wins (e.g. a jackpot banner).
    public let finale: SlotFinale?

    /// The all-win flourish: once every reel lands on `win`, the winning grid is flashed
    /// in place for a moment — bright on, dim off — so a jackpot reads as a celebration
    /// rather than just stopping. Configure how many times it blinks and how fast; a `nil`
    /// finale on the theme means no flash (the grid just settles).
    public struct SlotFinale: Sendable {
        /// Number of blink frames (each toggles the grid bright ↔ dim).
        public let frames: Int
        /// Seconds between blink frames.
        public let interval: Double

        /// Creates an all-win blink flourish.
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
        )
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
}
