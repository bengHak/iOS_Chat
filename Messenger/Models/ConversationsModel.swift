//
//  ConversationsModel.swift
//  Messenger
//
//  Created by byunghak on 2021/08/28.
//

import Foundation

struct Conversation {
    let id: String
    let name: String
    let otherUserEmail: String
    let latestMessage: LatestMessage
}

struct LatestMessage {
    let date: String
    let text: String
    let isRead: Bool
}
