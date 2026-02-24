import SwiftUI

struct NewListSheet: View {
    @Environment(\.dismiss) private var dismiss

    let userId: String
    let onCreate: (ShoppingList) -> Void

    @State private var listService: ListService
    @State private var listName = ""
    @FocusState private var isNameFocused: Bool

    init(
        userId: String,
        listService: ListService = ListService(),
        onCreate: @escaping (ShoppingList) -> Void
    ) {
        self.userId = userId
        self._listService = State(initialValue: listService)
        self.onCreate = onCreate
    }

    var body: some View {
        NavigationStack {
            Form {
                Section {
                    TextField("List Name", text: $listName)
                        .focused($isNameFocused)
                        .submitLabel(.done)
                        .onSubmit(createList)
                } header: {
                    Text("Name your list")
                }
            }
            .navigationTitle("New List")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cancel") {
                        dismiss()
                    }
                }

                ToolbarItem(placement: .confirmationAction) {
                    Button("Create") {
                        createList()
                    }
                    .disabled(listName.trimmingCharacters(in: .whitespaces).isEmpty)
                }
            }
            .onAppear {
                isNameFocused = true
            }
        }
        .presentationDetents([.height(200)])
    }

    private func createList() {
        let trimmedName = listName.trimmingCharacters(in: .whitespaces)
        guard !trimmedName.isEmpty else { return }

        let newList = listService.createList(name: trimmedName, createdBy: userId)
        onCreate(newList)
        dismiss()
    }
}

#Preview {
    NewListSheet(
        userId: "preview-user",
        listService: ListService(persistence: .preview),
        onCreate: { _ in }
    )
}
