/// One check shown as a single reel: a label and the async work that resolves it.
///
/// The reel spins until `work` returns; `true` locks it on the theme's win face,
/// `false` (or a thrown error) on the lose face.
public struct SlotReel: Sendable {
    /// The text shown beneath the reel.
    public let label: String
    /// The asynchronous check; its `Bool` result decides win/lose.
    public let work: @Sendable () async throws -> Bool

    /// Creates a reel from a label and its async check.
    public init(label: String, work: @escaping @Sendable () async throws -> Bool) {
        self.label = label
        self.work = work
    }
}

/// The resolved outcome of one reel after the spin completes.
public struct SlotOutcome: Sendable, Equatable {
    /// The reel's label.
    public let label: String
    /// Whether the reel's check passed.
    public let passed: Bool
}

/// The result of spinning every reel.
public struct SlotResult: Sendable, Equatable {
    /// Per-reel outcomes, in the order the reels were given.
    public let outcomes: [SlotOutcome]

    /// `true` when every reel passed.
    public var allPassed: Bool {
        outcomes.allSatisfy(\.passed)
    }

    /// Creates a result from per-reel outcomes.
    public init(outcomes: [SlotOutcome]) {
        self.outcomes = outcomes
    }
}
