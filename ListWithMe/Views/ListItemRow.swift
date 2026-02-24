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
                HStack {
                    TextField("Item", text: $text)
                        .strikethrough(item.isComplete)
                        .foregroundStyle(item.isComplete ? .secondary : .primary)
                        .focused($isFocused)
                        .onChange(of: text) { _, newValue in
                            onTextChange(newValue)
                        }
                        .submitLabel(.done)

                    // Quantity badge
                    if item.quantity > 1 {
                        Text("×\(item.quantity)")
                            .font(.caption.weight(.semibold))
                            .padding(.horizontal, 6)
                            .padding(.vertical, 2)
                            .background(Color.blue.opacity(0.2))
                            .clipShape(Capsule())
                    }

                    // Priority indicator
                    if item.priority != .none {
                        Image(systemName: item.priority.icon)
                            .font(.caption)
                            .foregroundStyle(priorityColor)
                    }

                    // Due date indicator
                    if let dueDate = item.dueDate {
                        HStack(spacing: 2) {
                            Image(systemName: "calendar")
                            Text(dueDate, style: .date)
                        }
                        .font(.caption2)
                        .foregroundStyle(dueDate < Date() ? .red : .secondary)
                    }

                    // Category badge
                    if let category = item.category, !category.isEmpty {
                        Text(category)
                            .font(.caption2)
                            .padding(.horizontal, 6)
                            .padding(.vertical, 2)
                            .background(Color.secondary.opacity(0.2))
                            .clipShape(Capsule())
                    }
                }

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

    private var priorityColor: Color {
        switch item.priority {
        case .none: return .secondary
        case .low: return .blue
        case .medium: return .orange
        case .high: return .red
        }
    }
}

#Preview {
    List {
        // Basic item with category
        ListItemRow(
            item: ListItem(text: "Milk", createdBy: "user1", category: "Dairy"),
            onToggleComplete: {},
            onTextChange: { _ in },
            onDelete: {}
        )
        // Item with quantity
        ListItemRow(
            item: ListItem(text: "Bananas", createdBy: "user1", category: "Produce", quantity: 6),
            onToggleComplete: {},
            onTextChange: { _ in },
            onDelete: {}
        )
        // Item with high priority
        ListItemRow(
            item: ListItem(text: "Birthday cake", createdBy: "user1", priority: .high),
            onToggleComplete: {},
            onTextChange: { _ in },
            onDelete: {}
        )
        // Item with due date (future)
        ListItemRow(
            item: ListItem(text: "Pick up prescription", createdBy: "user1", dueDate: Calendar.current.date(byAdding: .day, value: 2, to: Date())),
            onToggleComplete: {},
            onTextChange: { _ in },
            onDelete: {}
        )
        // Item with overdue date
        ListItemRow(
            item: ListItem(text: "Return library books", createdBy: "user1", dueDate: Calendar.current.date(byAdding: .day, value: -1, to: Date())),
            onToggleComplete: {},
            onTextChange: { _ in },
            onDelete: {}
        )
        // Item with all properties
        ListItemRow(
            item: ListItem(
                text: "Party supplies",
                createdBy: "user1",
                category: "Party",
                quantity: 3,
                dueDate: Calendar.current.date(byAdding: .day, value: 5, to: Date()),
                priority: .medium
            ),
            onToggleComplete: {},
            onTextChange: { _ in },
            onDelete: {}
        )
        // Completed item
        ListItemRow(
            item: {
                var item = ListItem(text: "Eggs", createdBy: "user1", quantity: 12, priority: .low)
                item.markComplete(by: "user2")
                return item
            }(),
            onToggleComplete: {},
            onTextChange: { _ in },
            onDelete: {}
        )
    }
}
