import SwiftUI

struct ListsView: View {
    let userId: String
    let onSelectList: (ShoppingList) -> Void
    let onCreateList: () -> Void

    @State private var listService: ListService

    init(
        userId: String,
        listService: ListService = ListService(),
        onSelectList: @escaping (ShoppingList) -> Void,
        onCreateList: @escaping () -> Void
    ) {
        self.userId = userId
        self._listService = State(initialValue: listService)
        self.onSelectList = onSelectList
        self.onCreateList = onCreateList
    }

    var body: some View {
        VStack(spacing: 0) {
            // Header
            HStack {
                Text("Your Lists")
                    .font(.headline)

                Spacer()

                Button(action: onCreateList) {
                    Image(systemName: "plus.circle.fill")
                        .font(.title2)
                }
            }
            .padding()
            .background(.ultraThinMaterial)

            if listService.lists.isEmpty {
                ContentUnavailableView(
                    "No Lists Yet",
                    systemImage: "list.bullet.rectangle",
                    description: Text("Tap + to create your first list")
                )
            } else {
                ScrollView {
                    LazyVGrid(
                        columns: [
                            GridItem(.flexible(), spacing: 12),
                            GridItem(.flexible(), spacing: 12)
                        ],
                        spacing: 12
                    ) {
                        ForEach(listService.lists) { list in
                            ListCard(list: list)
                                .onTapGesture {
                                    onSelectList(list)
                                }
                        }
                    }
                    .padding()
                }
            }
        }
    }
}

struct ListCard: View {
    let list: ShoppingList

    private var completionRatio: Double {
        guard !list.items.isEmpty else { return 0 }
        return Double(list.items.filter(\.isComplete).count) / Double(list.items.count)
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack {
                Text(list.name)
                    .font(.headline)
                    .lineLimit(1)

                Spacer()

                Text("\(list.items.count)")
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }

            // Preview of items
            VStack(alignment: .leading, spacing: 2) {
                ForEach(list.items.prefix(3)) { item in
                    HStack(spacing: 4) {
                        Image(systemName: item.isComplete ? "checkmark.circle.fill" : "circle")
                            .font(.caption2)
                            .foregroundStyle(item.isComplete ? .green : .secondary)

                        Text(item.text)
                            .font(.caption)
                            .lineLimit(1)
                            .strikethrough(item.isComplete)
                            .foregroundStyle(item.isComplete ? .secondary : .primary)
                    }
                }

                if list.items.count > 3 {
                    Text("+\(list.items.count - 3) more")
                        .font(.caption2)
                        .foregroundStyle(.tertiary)
                }
            }

            Spacer()

            // Progress bar
            GeometryReader { geo in
                ZStack(alignment: .leading) {
                    RoundedRectangle(cornerRadius: 2)
                        .fill(.secondary.opacity(0.2))

                    RoundedRectangle(cornerRadius: 2)
                        .fill(.green)
                        .frame(width: geo.size.width * completionRatio)
                }
            }
            .frame(height: 4)
        }
        .padding()
        .frame(height: 140)
        .background(.regularMaterial)
        .clipShape(RoundedRectangle(cornerRadius: 12))
    }
}

#Preview {
    ListsView(
        userId: "preview-user",
        listService: ListService(persistence: .preview),
        onSelectList: { _ in },
        onCreateList: {}
    )
}
