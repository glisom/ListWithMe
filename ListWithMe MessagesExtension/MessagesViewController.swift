//
//  MessagesViewController.swift
//  ListWithMe MessagesExtension
//
//  Created by Isom,Grant on 12/7/18.
//  Copyright © 2018 Grant Isom. All rights reserved.
//

import UIKit
import Messages

class MessagesViewController: MSMessagesAppViewController, UITableViewDelegate, UITableViewDataSource, UITextFieldDelegate {
    
    @IBOutlet weak var tableView: UITableView!
    let reuseIdentifier = "listItem"
    var list = List()
    var isNewList = false
    
    override func viewDidLoad() {
        super.viewDidLoad()
        tableView.delegate = self
        tableView.dataSource = self
        tableView.rowHeight = 80
        
        let addItemView = UIView(frame: CGRect(x: 0,
                                               y: 0,
                                               width: view.frame.width,
                                               height: 40))
        let addItemButton = UIButton(frame: CGRect(x: 16,
                                                   y: 0,
                                                   width: (addItemView.frame.width/2),
                                                   height: addItemView.frame.height))
        let updateButton = UIButton(frame: CGRect(x: view.frame.width - (addItemView.frame.width/2) - 16,
                                                  y: 0,
                                                  width: (addItemView.frame.width/2),
                                                  height: addItemView.frame.height))
        addItemButton.setTitle("Add New Item", for: .normal)
        addItemButton.setTitleColor(.gray, for: .normal)
        addItemButton.setTitleColor(.darkGray, for: .selected)
        addItemButton.contentHorizontalAlignment = .left
        addItemButton.titleLabel!.font = UIFont.boldSystemFont(ofSize: 15.0)
        addItemButton.addTarget(self, action: #selector(addItem), for: .touchUpInside)
        addItemView.addSubview(addItemButton)
        updateButton.setTitle("Send List", for: .normal)
        updateButton.setTitleColor(.gray, for: .normal)
        updateButton.setTitleColor(.darkGray, for: .selected)
        updateButton.contentHorizontalAlignment = .right
        updateButton.titleLabel!.font = UIFont.boldSystemFont(ofSize: 15.0)
        updateButton.addTarget(self, action: #selector(sendItems), for: .touchUpInside)
        addItemView.addSubview(updateButton)
        tableView.tableHeaderView =  addItemView
    }
    
    // MARK: - Table View Data Source
    
    func tableView(_ tableView: UITableView, numberOfRowsInSection section: Int) -> Int {
        if let listItems = list.listItems {
            return listItems.count
        }
        return 0
    }
    
    func numberOfSections(in tableView: UITableView) -> Int {
        return 1
    }
    
    // MARK: - Table View Delegate
    
    func tableView(_ tableView: UITableView, cellForRowAt indexPath: IndexPath) -> UITableViewCell {
        let cell =  (tableView.dequeueReusableCell(withIdentifier: reuseIdentifier, for: indexPath) as! ListItemCell)
        if let listItems = list.listItems {
            cell.textField.text = listItems[indexPath.row].text
            cell.textField.addTarget(self, action: #selector(dismissKeyboard), for: .editingDidEndOnExit)
            cell.textField.addTarget(self, action: #selector(expandView), for: .editingDidBegin)
            cell.textField.addTarget(self, action: #selector(updateText(_:)), for: .editingChanged)
            cell.textField.tag = indexPath.row
            if listItems[indexPath.row].isComplete {
                let attributeString: NSMutableAttributedString =  NSMutableAttributedString(string: cell.textField.text!)
                attributeString.addAttribute(NSAttributedString.Key.strikethroughStyle, value: 2, range: NSMakeRange(0, attributeString.length))
                cell.textField.attributedText = attributeString
                cell.textField.textColor = .gray
            }
        }
        return cell
    }
    
    func tableView(_ tableView: UITableView, leadingSwipeActionsConfigurationForRowAt indexPath: IndexPath) -> UISwipeActionsConfiguration? {
        let completeAction = UIContextualAction(style: .normal, title: "Complete") { (action, view, success:(Bool) -> Void) in
            let cell = tableView.cellForRow(at: indexPath) as! ListItemCell
            let attributeString: NSMutableAttributedString =  NSMutableAttributedString(string: cell.textField.text!)
            attributeString.addAttribute(NSAttributedString.Key.strikethroughStyle, value: 2, range: NSMakeRange(0, attributeString.length))
            cell.textField.attributedText = attributeString
            cell.textField.textColor = .gray
            self.list.listItems![indexPath.row].isComplete = true
            self.list.listItems![indexPath.row].lastEdit = self.activeConversation?.localParticipantIdentifier
            success(true)
        }
        completeAction.backgroundColor = UIColor(red:0.53, green:0.72, blue:0.36, alpha:1.00)
        return UISwipeActionsConfiguration(actions: [completeAction])
    }
    
    func tableView(_ tableView: UITableView, commit editingStyle: UITableViewCell.EditingStyle, forRowAt indexPath: IndexPath) {
        if editingStyle == .delete {
            list.listItems?.remove(at: indexPath.row)
            tableView.reloadData()
        }
    }
    
    @objc func addItem() {
        requestPresentationStyle(.expanded)
        if var listItems = list.listItems {
            let newItem = ListItem.init(text: "", isComplete: false, lastEdit: activeConversation?.localParticipantIdentifier)
            listItems.append(newItem)
            list.listItems = listItems
        } else {
            let newItem = ListItem.init(text: "", isComplete: false, lastEdit: activeConversation?.localParticipantIdentifier)
            list.listItems = [newItem]
        }
        tableView.reloadData()
    }
    
    @objc func sendItems() {
        guard let conversation = activeConversation else { fatalError("Expected a conversation") }
        var title = isNewList ? "New List" : "Updated List"
        if isNewList {
            let alert = UIAlertController.init(title: "Give this list a name?", message: "", preferredStyle: .alert)
            alert.addTextField { textField in
                textField.placeholder = "List Name"
            }
            let confirmAction = UIAlertAction(title: "Okay", style: .default) { [weak alert] _ in
                guard let alert = alert, let textField = alert.textFields?.first else { return }
                title = textField.text ?? "New List"
                self.requestPresentationStyle(.compact)
                let message = self.composeMessage(with: self.list, caption: "From $\(conversation.localParticipantIdentifier.uuidString)", session: conversation.selectedMessage?.session, title: title)
                conversation.insert(message) { error in
                    if let error = error {
                        print(error)
                    }
                }
            }
            alert.addAction(confirmAction)
            let cancelAction = UIAlertAction(title: "Cancel", style: .cancel, handler: nil)
            alert.addAction(cancelAction)
            present(alert, animated: true)
        } else {
            requestPresentationStyle(.compact)
            let message = composeMessage(with: list, caption: "From $\(conversation.localParticipantIdentifier.uuidString)", session: conversation.selectedMessage?.session, title: title)
            conversation.insert(message) { error in
                if let error = error {
                    print(error)
                }
            }
        }
        
    }
    
    fileprivate func composeMessage(with list: List, caption: String, session: MSSession? = nil, title: String) -> MSMessage {
        var components = URLComponents()
        components.queryItems = list.queryItems
        
        let layout = MSMessageTemplateLayout()
        layout.image = #imageLiteral(resourceName: "placeholder")
        layout.imageTitle = title
        layout.caption = caption
        let message = MSMessage(session: session ?? MSSession())
        message.url = components.url!
        message.layout = layout
        
        return message
    }
    
    // Mark: - UITextField Delegate
    
    @objc func dismissKeyboard(_ sender:UITextField) {
        sender.resignFirstResponder()
        list.listItems?[sender.tag].text = sender.text
        list.listItems?[sender.tag].lastEdit = activeConversation?.localParticipantIdentifier
    }
    
    @objc func updateText(_ sender:UITextField) {
        list.listItems?[sender.tag].text = sender.text
        list.listItems?[sender.tag].lastEdit = activeConversation?.localParticipantIdentifier
    }
    
    @objc func expandView() {
        requestPresentationStyle(.expanded)
    }
    
    // MARK: - Conversation Handling
    override func didBecomeActive(with conversation: MSConversation) {
        if let currentList = List(message: conversation.selectedMessage) {
            list = currentList
            tableView.reloadData()
        } else {
            isNewList = true
            list = List()
        }
    }
    
    override func didResignActive(with conversation: MSConversation) {
        // Called when the extension is about to move from the active to inactive state.
        // This will happen when the user dissmises the extension, changes to a different
        // conversation or quits Messages.
        
        // Use this method to release shared resources, save user data, invalidate timers,
        // and store enough state information to restore your extension to its current state
        // in case it is terminated later.
    }
   
    override func didReceive(_ message: MSMessage, conversation: MSConversation) {
        // Called when a message arrives that was generated by another instance of this
        // extension on a remote device.
        
        // Use this method to trigger UI updates in response to the message.
    }
    
    override func didStartSending(_ message: MSMessage, conversation: MSConversation) {
        // Called when the user taps the send button.
    }
    
    override func didCancelSending(_ message: MSMessage, conversation: MSConversation) {
        // Called when the user deletes the message without sending it.
    
        // Use this to clean up state related to the deleted message.
    }
    
    override func willTransition(to presentationStyle: MSMessagesAppPresentationStyle) {
        // Called before the extension transitions to a new presentation style.
    
        // Use this method to prepare for the change in presentation style.
        if presentationStyle == .compact {
            view.endEditing(true)
        }
    }
    
    override func didTransition(to presentationStyle: MSMessagesAppPresentationStyle) {
        // Called after the extension transitions to a new presentation style.
        // Use this method to finalize any behaviors associated with the change in presentation style.
    }

}
