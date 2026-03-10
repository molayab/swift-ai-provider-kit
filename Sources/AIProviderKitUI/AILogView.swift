import SwiftUI
import AIProviderKit

/// A SwiftUI view that displays live log entries from `AILogStore`.
///
/// Embed anywhere in your app's debug tooling. Requires `AILogStore.shared`
/// to be set at startup; shows an empty-state prompt otherwise.
///
/// ```swift
/// // In a settings or debug sheet:
/// AILogView(store: AILogStore.shared ?? AILogStore())
/// ```
public struct AILogView: View {

    @State private var store: AILogStore
    @State private var selectedLevels: Set<AILogLevel> = Set(AILogLevel.allCases)
    @State private var searchText: String = ""

    public init(store: AILogStore) {
        _store = State(initialValue: store)
    }

    private var filteredEntries: [AILogEntry] {
        store.entries
            .filter { selectedLevels.contains($0.level) }
            .filter { searchText.isEmpty || $0.message.localizedCaseInsensitiveContains(searchText) }
    }

    public var body: some View {
        NavigationStack {
            Group {
                if filteredEntries.isEmpty {
                    ContentUnavailableView(
                        "No Logs",
                        systemImage: "doc.text.magnifyingglass",
                        description: Text("Matching log entries will appear here.")
                    )
                } else {
                    ScrollViewReader { proxy in
                        List(filteredEntries) { entry in
                            AILogEntryRow(entry: entry)
                                .id(entry.id)
                        }
                        .listStyle(.plain)
                        .onChange(of: store.entries.count) {
                            if let last = filteredEntries.last {
                                withAnimation { proxy.scrollTo(last.id, anchor: .bottom) }
                            }
                        }
                    }
                }
            }
            .navigationTitle("AI Logs")
            .searchable(text: $searchText, prompt: "Filter messages")
            .toolbar {
                ToolbarItem(placement: .navigation) {
                    levelFilterMenu
                }
                ToolbarItem(placement: .primaryAction) {
                    Button("Clear", role: .destructive) {
                        store.clear()
                    }
                    .disabled(store.entries.isEmpty)
                }
            }
        }
    }

    private var levelFilterMenu: some View {
        Menu {
            ForEach(AILogLevel.allCases, id: \.self) { level in
                Button {
                    if selectedLevels.contains(level) {
                        selectedLevels.remove(level)
                    } else {
                        selectedLevels.insert(level)
                    }
                } label: {
                    Label(
                        level.rawValue.capitalized,
                        systemImage: selectedLevels.contains(level) ? "checkmark" : ""
                    )
                }
            }
        } label: {
            Label("Filter", systemImage: "line.3.horizontal.decrease.circle")
        }
    }
}

// MARK: - Entry Row

private struct AILogEntryRow: View {

    let entry: AILogEntry

    private static let timeFormatter: DateFormatter = {
        let formatter = DateFormatter()
        formatter.dateFormat = "HH:mm:ss.SSS"
        return formatter
    }()

    var body: some View {
        VStack(alignment: .leading, spacing: 2) {
            HStack(spacing: 6) {
                levelBadge
                Text(entry.category)
                    .font(.caption2)
                    .foregroundStyle(.secondary)
                Spacer()
                Text(Self.timeFormatter.string(from: entry.timestamp))
                    .font(.caption2.monospacedDigit())
                    .foregroundStyle(.secondary)
            }
            Text(entry.message)
                .font(.caption.monospaced())
                .foregroundStyle(messageColor)
                .textSelection(.enabled)
        }
        .padding(.vertical, 2)
    }

    private var levelBadge: some View {
        Text(entry.level.rawValue)
            .font(.caption2.bold())
            .padding(.horizontal, 5)
            .padding(.vertical, 2)
            .background(badgeColor.opacity(0.15), in: .capsule)
            .foregroundStyle(badgeColor)
    }

    private var badgeColor: Color {
        switch entry.level {
        case .info:    return .blue
        case .warning: return .orange
        case .error:   return .red
        }
    }

    private var messageColor: Color {
        switch entry.level {
        case .info:    return .primary
        case .warning: return .orange
        case .error:   return .red
        }
    }
}
