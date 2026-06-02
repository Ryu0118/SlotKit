/// One column of a skill-stop grid spin — it lands on whatever face is showing the instant
/// it is stopped, not on a predetermined symbol.
///
/// Where ``GridReel`` draws its landing symbol up front, a `SkillReel` carries only a **stop
/// signal**: its async `stop` returns when the player (or a timer) chooses to stop the
/// column, and the machine lands it on the face spinning by at that frame. The odds of a
/// given face live in the theme's ``SlotTheme/spinning`` pool — a weighted pool makes a rare
/// face genuinely hard to catch, the way a real machine does.
public struct SkillReel: Sendable {
    /// The caption shown beneath the column, or `nil` for none.
    public let label: String?
    /// Returns when the column should stop; the column lands on the face showing at that frame.
    public let stop: @Sendable () async -> Void

    /// Creates a labeled skill-stop column with its stop signal.
    public init(label: String, stop: @escaping @Sendable () async -> Void) {
        self.label = label
        self.stop = stop
    }

    /// Creates an unlabeled skill-stop column — just a spinning column and its stop signal.
    public init(_ stop: @escaping @Sendable () async -> Void) {
        label = nil
        self.stop = stop
    }
}
