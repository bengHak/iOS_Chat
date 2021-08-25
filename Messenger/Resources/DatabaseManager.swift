//
//  DatabaseManager.swift
//  Messenger
//
//  Created by byunghak on 2021/08/21.
//

import Foundation
import FirebaseDatabase
import MessageKit
import CoreLocation

final class DatabaseManager {

    // Singleton
    static let shared = DatabaseManager()
    
    // private let database = Database.database().reference()
    // region이 달라서 직접 설정해줘야한다
    private let database = Database.database(url: "https://messenger-96e06-default-rtdb.asia-southeast1.firebasedatabase.app/").reference()
    
    static func safeEmail(emailAddress: String) -> String {
        var safeEmail = emailAddress.replacingOccurrences(of: ".", with: "-")
        safeEmail = safeEmail.replacingOccurrences(of: "@", with: "-")
        return safeEmail
    }
}

extension DatabaseManager {
    
    public func getDataFor(path: String, completion: @escaping (Result<Any, Error>) -> Void) {
        self.database.child("\(path)").observeSingleEvent(of: .value) { snapshot in
            guard let value = snapshot.value else {
                completion(.failure(DatabaseError.failedToFetch))
                return
            }
            completion(.success(value))
        }
    }
}


// MARK: - Account Management
extension DatabaseManager {
    
    // MARK: User Exists
    public func userExtists(with email: String, completion: @escaping ((Bool) -> Void)) {
        let safeEmail = DatabaseManager.safeEmail(emailAddress: email)
        database.child(safeEmail).observeSingleEvent(of: .value, with: { snapshot in
            guard snapshot.value as? [String: Any] != nil else {
                completion(false)
                return
            }
            completion(true)
        })
    }
    
    // MARK: Insert User
    /// Inserts new user to database
    public func insertUser(with user: ChatAppUser, completion: @escaping (Bool) -> Void) {
        database.child(user.safeEmail).setValue([
            "first_name": user.firstName,
            "last_name": user.lastName
        ], withCompletionBlock: { error, _ in
            guard error == nil else {
                print("failed to write to database")
                completion(false)
                return
            }
            
            self.database.child("users").observeSingleEvent(of: .value) { snapshot in
                
                let newElement = [
                    "name": user.firstName + " " + user.lastName,
                    "email": user.safeEmail
                ]
                
                if var usersCollection = snapshot.value as? [[String:String]] {
                    // append to user dictionary
                    usersCollection.append(newElement)
                    self.database.child("users").setValue(usersCollection, withCompletionBlock: { error, _ in
                        guard error == nil else {
                            completion(false)
                            return
                        }
                        completion(true)
                    })
                } else {
                    // create that array
                    let newCollection: [[String:String]] = [newElement]
                    self.database.child("users").setValue(newCollection, withCompletionBlock: { error, _ in
                        guard error == nil else {
                            completion(false)
                            return
                        }
                        completion(true)
                    })
                }
            }
            
            completion(true)
        })
    }
    
    // MARK: Get All Users
    public func getAllUsers(completion: @escaping (Result<[[String:String]], Error>) -> Void) {
        database.child("users").observeSingleEvent(of: .value, with: { snapshot in
            guard let value = snapshot.value as? [[String:String]] else {
                completion(.failure(DatabaseError.failedToFetch))
                return
            }
            completion(.success(value))
        })
    }
    
    public enum DatabaseError: Error {
        case failedToFetch
    }
}

// MARK: - Sending messages / Create conversations
extension DatabaseManager {
    
    
    // MARK: Create new conversation
    /// Creates a new converstaion with target user email and first message sent
    public func createNewConversation(with otherUserEmail: String, name: String, firstMessage: Message, completion: @escaping (Bool) -> Void) {
        guard  let currentEmail = UserDefaults.standard.value(forKey: "email") as? String,
               let currentName = UserDefaults.standard.value(forKey: "name") as? String else {
            return
        }
        let safeEmail = DatabaseManager.safeEmail(emailAddress: currentEmail)
        let ref = database.child(safeEmail)
        let recipient_ref = database.child("\(otherUserEmail)/conversations")
        
        ref.observeSingleEvent(of: .value) { snapshot in
            guard var userNode = snapshot.value as? [String:Any] else {
                completion(false)
                print("🔴 User not found")
                return
            }
            
            let messageDate = firstMessage.sentDate
            let dateString = ChatViewController.dateFormatter.string(from: messageDate)
            var message = ""
            
            switch firstMessage.kind {
            case .text(let messageText):
                message = messageText
            case .attributedText(_):
                break
            case .photo(let mediaItem):
                if let targetUrlString = mediaItem.url?.absoluteString {
                    message = targetUrlString
                }
            case .video(_):
                break
            case .location(_):
                break
            case .emoji(_):
                break
            case .audio(_):
                break
            case .contact(_):
                break
            case .linkPreview(_):
                break
            case .custom(_):
                break
            }
            
            let conversationId = "conversation_\(firstMessage.messageId)"
            
            let newConversationData: [String:Any] = [
                "id": conversationId,
                "other_user_email": otherUserEmail,
                "name": name,
                "latest_message": [
                    "date": dateString,
                    "message": message,
                    "is_read": false
                ]
            ]
            
            let recipient_newConversationData: [String:Any] = [
                "id": conversationId,
                "other_user_email": safeEmail,
                "name": currentName,
                "latest_message": [
                    "date": dateString,
                    "message": message,
                    "is_read": false
                ]
            ]
            
            // Update recipient conversation entry
            recipient_ref.observeSingleEvent(of: .value) { snapshot in
                if var conversations = snapshot.value as? [[String:Any]] {
                    // append
                    conversations.append(recipient_newConversationData)
                    recipient_ref.setValue(conversations)
                } else {
                    // create
                    recipient_ref.setValue([recipient_newConversationData])
                }
            }
            
            // Update current user conversation entry
            if var conversations = userNode["converstaions"] as? [[String:Any]] {
                // conversaion array exists for current user
                // you should append
                conversations.append(newConversationData)
                ref.setValue(conversations) { [weak self] error, _ in
                    guard error == nil else {
                        completion(false)
                        return
                    }
                    self?.finishCreatingConversation(name: name,
                                                     converstaionID: conversationId,
                                                     firstMessage: firstMessage,
                                                     completion: completion)
                }
            } else {
                // conversation array does NOT exist
                // creat it
                userNode["conversations"] = [newConversationData]
                ref.setValue(userNode) { [weak self] error, _ in
                    guard error == nil else {
                        completion(false)
                        return
                    }
                    self?.finishCreatingConversation(name: name,
                                                     converstaionID: conversationId,
                                                     firstMessage: firstMessage,
                                                     completion: completion)
                }
                
            }
        }
    }
    
    // MARK: Finish creating conversation
    private func finishCreatingConversation(name: String, converstaionID: String, firstMessage: Message, completion: @escaping (Bool) -> Void) {
        
        let messageDate = firstMessage.sentDate
        let dateString = ChatViewController.dateFormatter.string(from: messageDate)
        guard let currentUserEmail = UserDefaults.standard.value(forKey: "email") as? String else {
            completion(false)
            return
        }
        let safeEmail = DatabaseManager.safeEmail(emailAddress: currentUserEmail)
        var message = ""
        switch firstMessage.kind {
        case .text(let messageText):
            message = messageText
        case .photo(let mediaItem):
            if let targetUrlString = mediaItem.url?.absoluteString {
                message = targetUrlString
            }
        default:
            break
        }
        
        let collectionMessage: [String: Any] = [
            "id": firstMessage.messageId,
            "type": firstMessage.kind.messageKindString,
            "content": message,
            "date": dateString,
            "sender_email": safeEmail,
            "is_read": false,
            "name": name
        ]
        
        let value: [String: Any]  = [
            "messages": [
                collectionMessage
            ]
        ]
        database.child("\(converstaionID)").setValue(value) { error, _ in
            guard error == nil else {
                completion(false)
                return
            }
            completion(true)
        }
    }
    
    // MARK: Send message
    /// Sends a message with target conversation and message
    public func sendMessage(to conversation: String, recipientEmail: String, name: String, newMessage: Message, completion: @escaping (Bool) -> Void) {
        // conversations에 메시지 추가
        let messageDate = newMessage.sentDate
        let dateString = ChatViewController.dateFormatter.string(from: messageDate)
        guard let currentUserEmail = UserDefaults.standard.value(forKey: "email") as? String else {
            completion(false)
            return
        }
        let safeEmail = DatabaseManager.safeEmail(emailAddress: currentUserEmail)
        var message = ""
        switch newMessage.kind {
        case .text(let messageText):
            message = messageText
        case .photo(let mediaItem):
            if let targetUrlString = mediaItem.url?.absoluteString {
                message = targetUrlString
            }
        case .video(let mediaItem):
            if let targetUrlString = mediaItem.url?.absoluteString {
                message = targetUrlString
            }
        case .location(let locationData):
            let location = locationData.location
            message = "\(location.coordinate.longitude),\(location.coordinate.latitude)"
        default:
            break
        }
        
        let newMessageEntry: [String: Any] = [
            "id": newMessage.messageId,
            "type": newMessage.kind.messageKindString,
            "content": message,
            "date": dateString,
            "sender_email": safeEmail,
            "is_read": false,
            "name": name
        ]
        
        self.database.child("\(conversation)/messages").observeSingleEvent(of: .value) { [weak self] snapshot in
            guard var currentMessages = snapshot.value as? [[String:Any]] else {
                completion(false)
                return
            }
            
            currentMessages.append(newMessageEntry)
            self?.database.child("\(conversation)/messages").setValue(currentMessages) { error, _ in
                guard error == nil else {
                    completion(false)
                    return
                }
                completion(true)
            }
        }
        
        // sender에 latest 메시지 추가
        self.database.child("\(safeEmail)/conversations").observeSingleEvent(of: .value) { [weak self] snapshot in
            var databaseEntryConversations = [[String:Any]]()
            let updatedLatestMessage: [String:Any] = [
                "message": message,
                "date": dateString,
                "is_read": false
            ]
            
            if var conversations = snapshot.value as? [[String:Any]] {
                let conversationIndex = conversations.indices.filter {
                    guard let conversationId = conversations[$0]["id"] as? String,
                          conversationId == conversation else {
                        return false
                    }
                    return true
                }.first
                
                if let index = conversationIndex,
                   var targetConversation = conversations[index] as? [String:Any] {
                    targetConversation["latest_message"] = updatedLatestMessage
                    conversations[index] = targetConversation
                    databaseEntryConversations = conversations
                } else {
                    let newConversationData: [String: Any] = [
                        "id": conversation,
                        "other_user_email": DatabaseManager.safeEmail(emailAddress: recipientEmail),
                        "name": name,
                        "latest_message": updatedLatestMessage
                    ]
                    conversations.append(newConversationData)
                    databaseEntryConversations = conversations
                }
            } else {
                let newConversationData: [String: Any] = [
                    "id": conversation,
                    "other_user_email": DatabaseManager.safeEmail(emailAddress: recipientEmail),
                    "name": name,
                    "latest_message": updatedLatestMessage
                ]
                databaseEntryConversations = [
                    newConversationData
                ]
            }
            
            self?.database.child("\(safeEmail)/conversations/").setValue(databaseEntryConversations) { [weak self] error, _ in
                guard error == nil else {
                    completion(false)
                    return
                }
                
                // recipient에 latest 메시지 추가
                self?.database.child("\(recipientEmail)/conversations").observeSingleEvent(of: .value) { [weak self] snapshot in
                    let updatedValue: [String: Any] = [
                        "date": dateString,
                        "is_read": false,
                        "message": message
                    ]
                    var databaseEntryConversations = [[String: Any]]()
                    
                    guard let currentName = UserDefaults.standard.value(forKey: "name") as? String else {
                        return
                    }
                    
                    if var otherUserConversations = snapshot.value as? [[String: Any]] {
                        var targetConversation: [String: Any]?
                        var position = 0
                        
                        for conversationDictionary in otherUserConversations {
                            if let currentId = conversationDictionary["id"] as? String, currentId == conversation {
                                targetConversation = conversationDictionary
                                break
                            }
                            position += 1
                        }
                        
                        if var targetConversation = targetConversation {
                            targetConversation["latest_message"] = updatedValue
                            otherUserConversations[position] = targetConversation
                            databaseEntryConversations = otherUserConversations
                        }
                        else {
                            // failed to find in current colleciton
                            let newConversationData: [String: Any] = [
                                "id": conversation,
                                "other_user_email": DatabaseManager.safeEmail(emailAddress: safeEmail),
                                "name": currentName,
                                "latest_message": updatedValue
                            ]
                            otherUserConversations.append(newConversationData)
                            databaseEntryConversations = otherUserConversations
                        }
                    }
                    else {
                        // current collection does not exist
                        let newConversationData: [String: Any] = [
                            "id": conversation,
                            "other_user_email": DatabaseManager.safeEmail(emailAddress: safeEmail),
                            "name": currentName,
                            "latest_message": updatedValue
                        ]
                        databaseEntryConversations = [
                            newConversationData
                        ]
                    }
                    
                    self?.database.child("\(recipientEmail)/conversations").setValue(databaseEntryConversations){ error, _ in
                        guard error == nil else {
                            completion(false)
                            return
                        }
                        
                        completion(true)
                    }
                    
                }
            }
        }
        
        print("🟢 send: \(safeEmail) 👉 \(recipientEmail)")
        completion(true)
    }
    
    // MARK: Get All Conversation
    /// Fetches and returns all conversation for the user with passed in email
    public func getAllConversations(for email: String, completion: @escaping (Result<[Conversation], Error>) -> Void) {
        database.child("\(email)/conversations").observe(.value) { snapshot in
            guard let value = snapshot.value as? [[String: Any]] else {
                completion(.failure(DatabaseError.failedToFetch))
                return
            }
            
            let conversations: [Conversation] = value.compactMap({ dictionary in
                guard let conversationId = dictionary["id"] as? String,
                      let name = dictionary["name"] as? String,
                      let otherUserEmail = dictionary["other_user_email"] as? String,
                      let latestMessage = dictionary["latest_message"] as? [String: Any],
                      let sent = latestMessage["date"] as? String,
                      let message = latestMessage["message"] as? String,
                      let isRead = latestMessage["is_read"] as? Bool else {
                    return nil
                }
                
                let latestMessageObject = LatestMessage(date: sent, text: message, isRead: isRead)
                return  Conversation(id: conversationId,
                                     name: name,
                                     otherUserEmail: otherUserEmail,
                                     latestMessage: latestMessageObject)
            })
            
            completion(.success(conversations))
        }
    }
    
    // MARK: Get All Messages
    /// Gets all messages for a given conversation
    public func getAllMessageForConversation(with id: String, completion: @escaping (Result<[Message], Error>) -> Void) {
        database.child("\(id)/messages").observe(.value) { snapshot in
            guard let value = snapshot.value as? [[String: Any]] else {
                completion(.failure(DatabaseError.failedToFetch))
                print("💩")
                return
            }
            
            let messages: [Message] = value.compactMap({ dictionary in
                guard let name = dictionary["name"] as? String,
//                      let isRead = dictionary["is_read"] as? Bool,
                      let messageID = dictionary["id"] as? String,
                      let content = dictionary["content"] as? String,
                      let senderEmail = dictionary["sender_email"] as? String,
                      let type = dictionary["type"] as? String,
                      let dateString = dictionary["date"] as? String,
                      let date = ChatViewController.dateFormatter.date(from: dateString) else {
                    print("🔴 MSG nil")
                    return nil
                }
                
                var kind: MessageKind?
                
                if type == "photo" {
                    guard  let imageUrl = URL(string: content),
                           let placeholder = UIImage(systemName: "plus") else {
                        return nil
                    }
                    let media = Media(url: imageUrl,
                                      image: nil,
                                      placeholderImage: placeholder,
                                      size: CGSize(width: 300, height: 300))
                    kind = .photo(media)
                } else if type == "video" {
                    guard let videoUrl = URL(string: content),
                          let placeholder = UIImage(named: "video_placeholder") else {
                        return nil
                    }
                    let media = Media(url: videoUrl,
                                      image: nil,
                                      placeholderImage: placeholder,
                                      size: CGSize(width: 300, height: 300))
                    kind = .video(media)
                } else if type == "location" {
                    let locationComponent = content.components(separatedBy: ",")
                    guard let longitude = Double(locationComponent[0]),
                          let latitude = Double(locationComponent[1]) else {
                        return nil
                    }
                    print("🟢 Rendering location; lat=\(latitude), long=\(longitude)")
                    let location = Location(location: CLLocation(latitude: latitude,
                                                                 longitude: longitude),
                                            size: CGSize(width: 300, height: 300))
                    kind = .location(location)
                } else {
                    kind = .text(content)
                }
                
                guard let finalKind = kind else { return nil }
                
                let sender = Sender(photoURL: "",
                                    senderId: senderEmail,
                                    displayName: name)
                
                return Message(sender: sender,
                               messageId: messageID,
                               sentDate: date,
                               kind: finalKind)
            })
            
            completion(.success(messages))
        }
    }
    
    // MARK: Delete Conversation
    public func deleteConverstaion(conversationId: String, completion: @escaping (Bool) -> Void) {
        guard let email = UserDefaults.standard.value(forKey: "email") as? String else {
            completion(false)
            return
        }
        let safeEmail = DatabaseManager.safeEmail(emailAddress: email)
        
        database.child("\(safeEmail)/conversations").observeSingleEvent(of: .value) { [weak self] snapshot in
            print("🔴 Deleting conversation with id: \(conversationId)")
            guard var value = snapshot.value as? [[String:Any]] else {
                completion(false)
                return
            }
            
            let positionToRemove = value.indices.filter {
                guard let id = value[$0]["id"] as? String, id == conversationId else {
                    return false
                }
                return true
            }.first
            
            if let index = positionToRemove {
                value.remove(at: index)
            }
            self?.database.child("\(safeEmail)/conversations").setValue(value) { error, _ in
                guard error == nil else {
                    completion(false)
                    return
                }
                completion(true)
            }
        }
    }
    
    // MARK: Check Conversation Exists
    public func conversationExists(with targetRecipientEmail: String, completion: @escaping (Result<String, Error>) -> Void) {
            let safeRecipientEmail = DatabaseManager.safeEmail(emailAddress: targetRecipientEmail)
            guard let senderEmail = UserDefaults.standard.value(forKey: "email") as? String else {
                return
            }
            let safeSenderEmail = DatabaseManager.safeEmail(emailAddress: senderEmail)

            database.child("\(safeRecipientEmail)/conversations").observeSingleEvent(of: .value, with: { snapshot in
                guard let collection = snapshot.value as? [[String: Any]] else {
                    completion(.failure(DatabaseError.failedToFetch))
                    return
                }

                // iterate and find conversation with target sender
                if let conversation = collection.first(where: {
                    guard let targetSenderEmail = $0["other_user_email"] as? String else {
                        return false
                    }
                    return safeSenderEmail == targetSenderEmail
                }) {
                    // get id
                    guard let id = conversation["id"] as? String else {
                        completion(.failure(DatabaseError.failedToFetch))
                        return
                    }
                    completion(.success(id))
                    return
                }

                completion(.failure(DatabaseError.failedToFetch))
                return
            })
        }
}


struct ChatAppUser {
    let firstName: String
    let lastName: String
    let emailAddress: String
    
    var safeEmail: String {
        var safeEmail = emailAddress.replacingOccurrences(of: ".", with: "-")
        safeEmail = safeEmail.replacingOccurrences(of: "@", with: "-")
        return safeEmail
    }
    
    var profilePictureFileName: String {
        return "\(safeEmail)_profile_picture.jpeg"
    }
}
