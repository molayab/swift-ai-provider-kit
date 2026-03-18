/// Prunes the oldest turns from a conversation until the estimated token count
/// fits within the given budget.
///
/// Turns are removed from the beginning of the list (oldest-first). Turns without
/// token usage are counted as zero and are never forcibly removed unless the
/// budget would still be exceeded after removing all counted turns.
enum TokenBudgetTrimmer {

    /// Returns a copy of `turns` trimmed so that the total token count ≤ `budget`.
    ///
    /// - Parameters:
    ///   - turns: Ordered list of turns, oldest first.
    ///   - budget: Maximum number of tokens to allow.
    /// - Returns: A trimmed list, maintaining chronological order.
    static func trim(_ turns: [ConversationTurn], toBudget budget: Int) -> [ConversationTurn] {
        var result = turns
        while totalTokens(result) > budget, !result.isEmpty {
            result.removeFirst()
        }
        return result
    }

    private static func totalTokens(_ turns: [ConversationTurn]) -> Int {
        turns.compactMap(\.tokenUsage).reduce(0) { $0 + $1.totalTokens }
    }
}
