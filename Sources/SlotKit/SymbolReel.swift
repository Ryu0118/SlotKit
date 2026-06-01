/// One reel in symbol-matching mode: an optional label and the async work that picks the
/// face it lands on.
///
/// Unlike ``SlotReel`` — whose `Bool` result only ever lands on the theme's win or lose
/// face — a symbol reel resolves to an **index into the theme's ``SlotTheme/symbols``**, so
/// each reel can stop on any face. A win is then "every reel landed on the same symbol"
/// (and a jackpot is "every reel landed on ``SlotTheme/jackpotIndex``"), which is what a
/// real slot machine does. The caller supplies the draw; SlotKit only animates the reveal.
public struct SymbolReel: Sendable {
    /// The text shown beneath the reel, or `nil` for no caption.
    public let label: String?
    /// The asynchronous draw; its result is the index into ``SlotTheme/symbols`` to land on.
    public let landing: @Sendable () async -> Int

    /// Creates a labeled symbol reel with its async draw.
    public init(label: String, landing: @escaping @Sendable () async -> Int) {
        self.label = label
        self.landing = landing
    }

    /// Creates an unlabeled symbol reel — just a spinning reel and its async draw.
    public init(_ landing: @escaping @Sendable () async -> Int) {
        label = nil
        self.landing = landing
    }
}

/// The resolved outcome of one symbol reel after the spin completes.
public struct SymbolOutcome: Sendable, Equatable {
    /// The reel's label, or `nil` if the reel was unlabeled.
    public let label: String?
    /// The index into ``SlotTheme/symbols`` the reel landed on.
    public let landedIndex: Int

    /// Creates a symbol outcome.
    public init(label: String?, landedIndex: Int) {
        self.label = label
        self.landedIndex = landedIndex
    }
}

/// The result of spinning every symbol reel.
public struct SymbolSpinResult: Sendable, Equatable {
    /// Per-reel outcomes, in the order the reels were given.
    public let outcomes: [SymbolOutcome]
    /// The jackpot symbol index this spin was judged against, or `nil` if the theme set none.
    public let jackpotIndex: Int?

    /// `true` when every reel landed on the same symbol (a winning line). Always `false`
    /// for an empty spin.
    public var allSame: Bool {
        guard let first = outcomes.first else { return false }
        return outcomes.allSatisfy { $0.landedIndex == first.landedIndex }
    }

    /// `true` when every reel landed on the jackpot symbol — the top-paying line. `false`
    /// when the theme singled out no jackpot, or any reel landed elsewhere.
    public var isJackpot: Bool {
        guard let jackpotIndex, !outcomes.isEmpty else { return false }
        return outcomes.allSatisfy { $0.landedIndex == jackpotIndex }
    }

    /// Creates a result from per-reel outcomes and the jackpot index they were judged against.
    public init(outcomes: [SymbolOutcome], jackpotIndex: Int?) {
        self.outcomes = outcomes
        self.jackpotIndex = jackpotIndex
    }
}
