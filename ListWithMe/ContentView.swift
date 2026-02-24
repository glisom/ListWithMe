import SwiftUI

struct ContentView: View {
    @State private var listService = ListService()
    @State private var selectedList: ShoppingList?
    @State private var showNewListSheet = false

    private let userId = UIDevice.current.identifierForVendor?.uuidString ?? "unknown"

    var body: some View {
        NavigationStack {
            ListsView(
                userId: userId,
                listService: listService,
                onSelectList: { list in
                    selectedList = list
                },
                onCreateList: {
                    showNewListSheet = true
                }
            )
            .navigationTitle("ListWithMe")
            .navigationDestination(item: $selectedList) { list in
                ListDetailView(
                    listId: list.id,
                    userId: userId,
                    listService: listService,
                    onSendList: { _ in
                        // In standalone app, could share via share sheet
                    }
                )
                .navigationTitle(list.name)
            }
            .sheet(isPresented: $showNewListSheet) {
                NewListSheet(
                    userId: userId,
                    listService: listService
                ) { newList in
                    selectedList = newList
                }
            }
        }
    }
}

#Preview {
    ContentView()
}
