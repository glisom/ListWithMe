import SwiftUI

struct ListItemRow: View {
    let item: ListItem
    let onToggleComplete: () -> Void
    let onTextChange: (String) -> Void
    let onDelete: () -> Void

    @State private var text: String
    @FocusState private var isFocused: Bool

    init(
        item: ListItem,
        onToggleComplete: @escaping () -> Void,
        onTextChange: @escaping (String) -> Void,
        onDelete: @escaping () -> Void
    ) {
        self.item = item
        self.onToggleComplete = onToggleComplete
        self.onTextChange = onTextChange
        self.onDelete = onDelete
        self._text = State(initialValue: item.text)
    }

    var body: some View {
        HStack(spacing: 12) {
            Button(action: onToggleComplete) {
                Image(systemName: item.isComplete ? "checkmark.circle.fill" : "circle")
                    .font(.title2)
                    .foregroundStyle(item.isComplete ? .green : .secondary)
                    .contentTransition(.symbolEffect(.replace))
            }
            .buttonStyle(.plain)

            VStack(alignment: .leading, spacing: 2) {
                TextField("Item", text: $text)
                    .strikethrough(item.isComplete)
                    .foregroundStyle(item.isComplete ? .secondary : .primary)
                    .focused($isFocused)
                    .onChange(of: text) { _, newValue in
                        onTextChange(newValue)
                    }
                    .submitLabel(.done)

                if !item.modifiedBy.isEmpty {
                    Text(modifiedByLabel)
                        .font(.caption2)
                        .foregroundStyle(.tertiary)
                }
            }
        }
        .padding(.vertical, 4)
        .contentShape(Rectangle())
        .swipeActions(edge: .trailing, allowsFullSwipe: true) {
            Button(role: .destructive, action: onDelete) {
                Label("Delete", systemImage: "trash")
            }
        }
        .swipeActions(edge: .leading, allowsFullSwipe: true) {
            Button(action: onToggleComplete) {
                Label(
                    item.isComplete ? "Undo" : "Done",
                    systemImage: item.isComplete ? "arrow.uturn.backward" : "checkmark"
                )
            }
            .tint(.green)
        }
    }

    private var modifiedByLabel: String {
        let shortId = String(item.modifiedBy.prefix(4))
        return "Edited by \(shortId)..."
    }
}

#Preview {
    List {
        ListItemRow(
            item: ListItem(text: "Milk", createdBy: "user1"),
            onToggleComplete: {},
            onTextChange: { _ in },
            onDelete: {}
        )
        ListItemRow(
            item: {
                var item = ListItem(text: "Eggs", createdBy: "user1")
                item.markComplete(by: "user2")
                return item
            }(),
            onToggleComplete: {},
            onTextChange: { _ in },
            onDelete: {}
        )
    }
}
