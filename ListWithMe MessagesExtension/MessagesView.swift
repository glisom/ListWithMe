import SwiftUI
import Messages

struct MessagesView: View {
    let conversation: MSConversation?
    let presentationStyle: MSMessagesAppPresentationStyle
    let onSendMessage: (MSMessage) -> Void
    let onRequestExpanded: () -> Void

    @State private var listService = ListService()
    @State private var collaborationService = CollaborationService()
    @State private var selectedList: ShoppingList?
    @State private var showNewListSheet = false

    private var userId: String {
        // Prefer CollaborationService's currentUserId (from CloudKit) if available,
        // otherwise fall back to conversation's local participant identifier
        if !collaborationService.currentUserId.isEmpty {
            return collaborationService.currentUserId
        }
        return conversation?.localParticipantIdentifier.uuidString ?? "unknown"
    }

    private var userName: String {
        collaborationService.currentUserName
    }

    var body: some View {
        Group {
            if presentationStyle == .compact {
                compactView
            } else {
                expandedView
            }
        }
        .sheet(isPresented: $showNewListSheet) {
            NewListSheet(
                userId: userId,
                listService: listService
            ) { newList in
                selectedList = newList
            }
        }
        .onAppear {
            configureListServiceUser()
        }
        .onChange(of: collaborationService.currentUserId) { _, _ in
            configureListServiceUser()
        }
        .onChange(of: collaborationService.currentUserName) { _, _ in
            configureListServiceUser()
        }
    }

    private func configureListServiceUser() {
        listService.currentUserId = userId
        listService.currentUserName = userName
    }

    private var compactView: some View {
        ListsView(
            userId: userId,
            listService: listService,
            onSelectList: { list in
                selectedList = list
                onRequestExpanded()
            },
            onCreateList: {
                showNewListSheet = true
                onRequestExpanded()
            }
        )
    }

    private var expandedView: some View {
        Group {
            if let list = selectedList {
                ListDetailView(
                    listId: list.id,
                    userId: userId,
                    listService: listService,
                    collaborationService: collaborationService,
                    onSendList: { list in
                        let message = composeMessage(for: list)
                        onSendMessage(message)
                    },
                    onBack: {
                        selectedList = nil
                    }
                )
            } else {
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
            }
        }
    }

    private func composeMessage(for list: ShoppingList) -> MSMessage {
        let message = MSMessage(session: conversation?.selectedMessage?.session ?? MSSession())

        let layout = MSMessageTemplateLayout()
        layout.caption = list.name
        layout.subcaption = "\(list.items.count) items"
        layout.trailingSubcaption = "\(list.items.filter(\.isComplete).count) done"

        // Store list ID in URL for retrieval
        var components = URLComponents()
        components.queryItems = [
            URLQueryItem(name: "listId", value: list.id.uuidString)
        ]

        message.url = components.url
        message.layout = layout

        return message
    }
}

#Preview {
    MessagesView(
        conversation: nil,
        presentationStyle: .expanded,
        onSendMessage: { _ in },
        onRequestExpanded: {}
    )
}
