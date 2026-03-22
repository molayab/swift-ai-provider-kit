/// Prunes turns from a conversation until the estimated token count fits within
/// the given budget.
///
/// The trimmer preferentially removes turns that carry a non-nil `tokenUsage`
/// (oldest counted turn first). Turns without token usage are counted as zero
/// and are only removed when no counted turn remains to satisfy the budget.
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
        var result = turns
        while totalTokens(result) > budget, !result.isEmpty {
            // Prefer removing the oldest turn that has a counted token cost.
            // Fall back to the oldest uncounted turn only when all remaining
            // turns have nil usage (budget still exceeded by uncounted turns).
            if let idx = result.firstIndex(where: { $0.tokenUsage != nil }) {
                result.remove(at: idx)
            } else {
                result.removeFirst()
            }
        }
        return result
    }

    private static func totalTokens(_ turns: [ConversationTurn]) -> Int {
        turns.compactMap(\.tokenUsage).reduce(0) { $0 + $1.totalTokens }
    }
}
