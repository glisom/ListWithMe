//
//  ListItem.swift
//  ListWithMe MessagesExtension
//
//  Created by Isom,Grant on 12/7/18.
//  Copyright © 2018 Grant Isom. All rights reserved.
//

import Foundation
import Messages

struct ListItem {
    
    var text: String?
    
    var isComplete: Bool?
    
    var lastEdit: UUID?
    
}

extension ListItem {
    
    var queryItems: [URLQueryItem] {
        var items = [URLQueryItem]()
        
        if text != nil {
            items.append(URLQueryItem(name: "text", value: text))
        }
        if isComplete != nil {
            items.append(URLQueryItem(name: "isComplete", value: (isComplete ?? false) ? "true" : "false"))
        }
        if lastEdit != nil {
            items.append(URLQueryItem(name: "lastEdit", value: lastEdit?.uuidString))
        }
        
        return items
    }
    
    init?(queryItems: [URLQueryItem]) {
        var text: String?
        var isComplete: Bool?
        var lastEdit: UUID?
        
        for queryItem in queryItems {
            guard let value = queryItem.value else { continue }
            
            if queryItem.name == "text" {
                text = value
            }
            if queryItem.name == "isComplete" {
                isComplete = (value == "true")
            }
            if queryItem.name == "lastEdit" {
                lastEdit = UUID.init(uuidString: value)
            }
        }
        self.text = text
        self.isComplete = isComplete
        self.lastEdit = lastEdit
    }
}

struct List {
    
    var listItems: [ListItem]?
    
}

extension List {
    var queryItems: [URLQueryItem] {
        var items = [URLQueryItem]()
        
        if let listItems = listItems {
            for listItem in listItems {
                items += listItem.queryItems
            }
        }
        
        return items
    }
    
    init?(queryItems: [URLQueryItem]) {
        var listItems = [ListItem]()
        if queryItems.count % 3 == 0 {
            var count = 0
            var subArray = [URLQueryItem]()
            for queryItem in queryItems {
                if count != 2 {
                    subArray.append(queryItem)
                } else {
                    let listItem = ListItem(queryItems: subArray)
                    if let listItem = listItem {
                        listItems.append(listItem)
                    }
                    subArray = [queryItem]
                    count = 0
                }
                count += 1
            }
        }
        self.listItems = listItems
    }
    
    init?(message: MSMessage?) {
        guard let messageURL = message?.url else { return nil }
        guard let urlComponents = NSURLComponents(url: messageURL, resolvingAgainstBaseURL: false) else { return nil }
        guard let queryItems = urlComponents.queryItems else { return nil }
        self.init(queryItems: queryItems)
    }
}
