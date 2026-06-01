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

    /// A jackpot-style flourish shown once all reels land on `win`.
    public struct SlotFinale: Sendable {
        /// The text scrolled through the colorizer.
        public let text: String
        /// Number of flashing frames.
        public let frames: Int
        /// Seconds between flourish frames.
        public let interval: Double

        /// Creates a finale flourish.
        public init(text: String, frames: Int = 12, interval: Double = 0.046) {
            self.text = text
            self.frames = frames
            self.interval = interval
        }
    }

    private init(
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
    }

    /// Builds a validated theme. Every symbol (spinning, win, lose) must have exactly
    /// `cellHeight` rows, each `cellWidth` characters wide; otherwise this throws
    /// ``SlotThemeError`` rather than letting reels clip or misalign at render time.
    public static func make(_ configure: (inout Draft) -> Void) throws -> SlotTheme {
        var draft = Draft()
        configure(&draft)
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
