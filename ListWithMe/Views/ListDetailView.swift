import SwiftUI

struct ListDetailView: View {
    let listId: UUID
    let userId: String
    let onSendList: (ShoppingList) -> Void

    @State private var listService: ListService
    @State private var collaborationService: CollaborationService
    @State private var newItemText = ""
    @State private var showActivitySheet = false
    @FocusState private var isAddingItem: Bool

    init(
        listId: UUID,
        userId: String,
        listService: ListService = ListService(),
        collaborationService: CollaborationService = CollaborationService(),
        onSendList: @escaping (ShoppingList) -> Void
    ) {
        self.listId = listId
        self.userId = userId
        self._listService = State(initialValue: listService)
        self._collaborationService = State(initialValue: collaborationService)
        self.onSendList = onSendList
    }

    private var list: ShoppingList? {
        listService.lists.first { $0.id == listId }
    }

    var body: some View {
        VStack(spacing: 0) {
            if let list = list {
                // Header
                headerView(for: list)

                // Items List
                List {
                    ForEach(list.items) { item in
                        ListItemRow(
                            item: item,
                            onToggleComplete: {
                                withAnimation(.spring(response: 0.3)) {
                                    listService.toggleItemComplete(item, in: listId, by: userId)
                                }
                            },
                            onTextChange: { newText in
                                var updated = item
                                updated.text = newText
                                updated.modifiedBy = userId
                                updated.modifiedAt = Date()
                                listService.updateItem(updated, in: listId)
                            },
                            onDelete: {
                                withAnimation {
                                    listService.deleteItem(item, from: listId)
                                }
                            }
                        )
                    }

                    // Add item row
                    addItemRow
                }
                .listStyle(.plain)

                // Send button
                sendButton(for: list)
            } else {
                ContentUnavailableView(
                    "List Not Found",
                    systemImage: "list.bullet",
                    description: Text("This list may have been deleted.")
                )
            }
        }
        .sheet(isPresented: $showActivitySheet) {
            ActivityFeedView(activities: listService.getActivities(for: listId))
        }
        .onAppear {
            collaborationService.startPresenceUpdates(for: listId)
        }
        .onDisappear {
            collaborationService.stopPresenceUpdates(for: listId)
        }
    }

    private func headerView(for list: ShoppingList) -> some View {
        HStack {
            Text(list.name)
                .font(.headline)

            Spacer()

            ParticipantsView(participants: collaborationService.getParticipants(for: listId))

            Text("\(list.items.filter { $0.isComplete }.count)/\(list.items.count)")
                .font(.subheadline)
                .foregroundStyle(.secondary)

            Button {
                showActivitySheet = true
            } label: {
                Image(systemName: "clock.arrow.circlepath")
                    .font(.title3)
            }
        }
        .padding()
        .background(.ultraThinMaterial)
    }

    private var addItemRow: some View {
        HStack(spacing: 12) {
            Image(systemName: "plus.circle.fill")
                .font(.title2)
                .foregroundStyle(.blue)

            TextField("Add item...", text: $newItemText)
                .focused($isAddingItem)
                .submitLabel(.done)
                .onSubmit(addItem)
        }
        .padding(.vertical, 4)
    }

    private func sendButton(for list: ShoppingList) -> some View {
        Button(action: { onSendList(list) }) {
            Label("Send List", systemImage: "paperplane.fill")
                .frame(maxWidth: .infinity)
                .padding()
        }
        .buttonStyle(.borderedProminent)
        .padding()
    }

    private func addItem() {
        guard !newItemText.trimmingCharacters(in: .whitespaces).isEmpty else { return }

        withAnimation {
            listService.addItem(to: listId, text: newItemText, createdBy: userId)
        }
        newItemText = ""
        isAddingItem = true
    }
}

#Preview {
    let service = ListService(persistence: .preview)
    let previewList = service.lists.first!

    return ListDetailView(
        listId: previewList.id,
        userId: "preview-user",
        listService: service,
        onSendList: { _ in }
    )
}
