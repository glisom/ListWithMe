import UIKit
import SwiftUI
import Messages

class MessagesViewController: MSMessagesAppViewController {

    private var hostingController: UIHostingController<MessagesView>?

    override func viewDidLoad() {
        super.viewDidLoad()
        setupHostingController()
    }

    private func setupHostingController() {
        let messagesView = MessagesView(
            conversation: activeConversation,
            presentationStyle: presentationStyle,
            onSendMessage: { [weak self] message in
                self?.sendMessage(message)
            },
            onRequestExpanded: { [weak self] in
                self?.requestPresentationStyle(.expanded)
            }
        )

        let hostingController = UIHostingController(rootView: messagesView)
        addChild(hostingController)
        view.addSubview(hostingController.view)

        hostingController.view.translatesAutoresizingMaskIntoConstraints = false
        NSLayoutConstraint.activate([
            hostingController.view.topAnchor.constraint(equalTo: view.topAnchor),
            hostingController.view.bottomAnchor.constraint(equalTo: view.bottomAnchor),
            hostingController.view.leadingAnchor.constraint(equalTo: view.leadingAnchor),
            hostingController.view.trailingAnchor.constraint(equalTo: view.trailingAnchor)
        ])

        hostingController.didMove(toParent: self)
        self.hostingController = hostingController
    }

    private func updateHostingController() {
        hostingController?.rootView = MessagesView(
            conversation: activeConversation,
            presentationStyle: presentationStyle,
            onSendMessage: { [weak self] message in
                self?.sendMessage(message)
            },
            onRequestExpanded: { [weak self] in
                self?.requestPresentationStyle(.expanded)
            }
        )
    }

    private func sendMessage(_ message: MSMessage) {
        activeConversation?.insert(message) { error in
            if let error = error {
                print("Failed to send message: \(error)")
            }
        }
        requestPresentationStyle(.compact)
    }

    // MARK: - Conversation Handling

    override func willBecomeActive(with conversation: MSConversation) {
        updateHostingController()
    }

    override func didBecomeActive(with conversation: MSConversation) {
        // Handle incoming message if present
        if let message = conversation.selectedMessage,
           let url = message.url,
           let components = URLComponents(url: url, resolvingAgainstBaseURL: false),
           let listIdString = components.queryItems?.first(where: { $0.name == "listId" })?.value,
           let listId = UUID(uuidString: listIdString) {
            // List ID is now stored in CloudKit, the SwiftUI view will fetch it
            print("Opening list: \(listId)")
        }
        updateHostingController()
    }

    override func willTransition(to presentationStyle: MSMessagesAppPresentationStyle) {
        updateHostingController()
    }

    override func didTransition(to presentationStyle: MSMessagesAppPresentationStyle) {
        updateHostingController()
    }
}
