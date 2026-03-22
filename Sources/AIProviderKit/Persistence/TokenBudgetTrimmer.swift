/// Prunes turns from a conversation until the estimated token count fits within
/// the given budget.
///
/// The trimmer preferentially removes turns that carry a non-nil `tokenUsage`
/// (oldest counted turn first). Turns without token usage are counted as zero
/// and are only removed when no counted turn remains to satisfy the budget.
/// The algorithm runs in O(n) time.
enum TokenBudgetTrimmer {

    /// Returns a copy of `turns` trimmed so that the total token count ≤ `budget`.
    ///
    /// Turns with a non-nil `tokenUsage` are removed before turns whose usage is
    /// `nil`. Within each group, the oldest turn is removed first.
    ///
    /// - Parameters:
    ///   - turns: Ordered list of turns, oldest first.
    ///   - budget: Maximum number of tokens to allow.
    /// - Returns: A trimmed list, maintaining chronological order.
    static func trim(_ turns: [ConversationTurn], toBudget budget: Int) -> [ConversationTurn] {
        // Compute the total token count once instead of recalculating each iteration.
        var total = turns.compactMap(\.tokenUsage).reduce(0) { $0 + $1.totalTokens }
        guard total > budget else { return turns }

        var keep = Array(repeating: true, count: turns.count)

        // Phase 1: single forward pass — remove oldest counted turns until budget is met.
        for (idx, turn) in turns.enumerated() {
            guard total > budget else { break }
            if let usage = turn.tokenUsage {
                total -= usage.totalTokens
                keep[idx] = false
            }
        }

        // Phase 2: only reachable when budget < 0 (total reached 0 but still exceeds
        // a negative budget). Remove remaining uncounted turns as a last resort.
        if total > budget {
            for (idx, turn) in turns.enumerated() where keep[idx] && turn.tokenUsage == nil {
                keep[idx] = false
            }
        }

        return zip(turns, keep).compactMap { $1 ? $0 : nil }
    }
}
