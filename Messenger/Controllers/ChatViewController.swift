//
//  ChatViewController.swift
//  Messenger
//
//  Created by byunghak on 2021/08/21.
//

import UIKit
import MessageKit
import InputBarAccessoryView
import SDWebImage
import AVFoundation
import AVKit
import CoreLocation

class ChatViewController: MessagesViewController {
    
    private var senderPhotoUrl: URL?
    private var otherUserPhotoUrl: URL?
    
    public static let dateFormatter: DateFormatter = {
        let formatter = DateFormatter()
        formatter.dateStyle = .long
        formatter.timeStyle = .short
        formatter.locale = Locale(identifier: "ko")
        return formatter
    }()
    
    public var isNewConversation = false
    
    public let otherUserEmail: String
    
    public var conversationId: String?
    
    private var messages = [Message]()
    
    private var selfSender: Sender? {
        guard let email = UserDefaults.standard.value(forKey: "email") as? String else {
            return nil
        }
        let safeEmail = DatabaseManager.safeEmail(emailAddress: email)
        return Sender(photoURL: "",
                      senderId: safeEmail,
                      displayName: "Me")
    }
    
// MARK: - Init
    init(with email: String, id: String?) {
        self.conversationId = id
        self.otherUserEmail = email
        super.init(nibName: nil, bundle: nil)
    }
    
    required init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }
    
// MARK: - Lifecycles
    override func viewDidLoad() {
        super.viewDidLoad()
        messagesCollectionView.messagesDataSource = self
        messagesCollectionView.messagesLayoutDelegate = self
        messagesCollectionView.messagesDisplayDelegate = self
        messagesCollectionView.messageCellDelegate = self
        messageInputBar.delegate = self
        setupInputButton()
    }
    
    override func viewDidAppear(_ animated: Bool) {
        super.viewDidAppear(true)
        messageInputBar.inputTextView.becomeFirstResponder()
        if let conversationId = conversationId {
            listeningForMessages(id: conversationId, shouldScrollToBottom: true)
        }
    }
    
    
// MARK: Setup
    private func setupInputButton() {
        let button = InputBarButtonItem()
        button.setSize(CGSize(width: 35, height: 35), animated: false)
        button.setImage(UIImage(systemName: "paperclip"), for: .normal)
        button.onTouchUpInside{ [weak self] _ in
            self?.presentInputActionSheet()
        }
        messageInputBar.setLeftStackViewWidthConstant(to: 36, animated: false)
        messageInputBar.setStackViewItems([button], forStack: .left, animated: false)
    }

    // MARK: - Methods
    private func presentInputActionSheet() {
        let actionSheet = UIAlertController(title: "Attach Media",
                                            message: "What would you like to attach?",
                                            preferredStyle: .actionSheet)
        actionSheet.addAction(UIAlertAction(title: "Photo", style: .default, handler: { [weak self] _ in
            self?.presentPhotoInputActionSheet()
        }))
        actionSheet.addAction(UIAlertAction(title: "Video", style: .default, handler: { [weak self] _ in
            self?.presentVideoInputActionSheet()
        }))
        actionSheet.addAction(UIAlertAction(title: "Location", style: .default, handler: { [weak self] _ in
            self?.presentLocationPicker()
        }))
//        actionSheet.addAction(UIAlertAction(title: "Audio", style: .default, handler: { [weak self] _ in
//
//        }))
//        actionSheet.addAction(UIAlertAction(title: "Cancle", style: .default, handler: { [weak self] _ in
//            actionSheet.dismiss(animated: true, completion: nil)
//        }))
        
        present(actionSheet, animated: true)
    }
    
    private func presentLocationPicker() {
        let vc = LocationPickerViewController(coordinates: nil)
        vc.title = "Pick Location"
        vc.navigationItem.largeTitleDisplayMode = .never
        vc.completion = { [weak self] selectedCoordinate in
            
            guard let messageId = self?.createMessageId(),
                  let conversationId = self?.conversationId,
                  let name = self?.title,
                  let selfSender = self?.selfSender else {
                return
            }
            
            let longitude: Double = selectedCoordinate.longitude
            let latitude: Double = selectedCoordinate.latitude
            
            print("\(longitude), \(latitude)")
            let locationData = Location(location: CLLocation(latitude: latitude, longitude: longitude),
                                 size: .zero)
            let message = Message(sender: selfSender,
                                  messageId: messageId,
                                  sentDate: Date(),
                                  kind: .location(locationData))
            
            DatabaseManager.shared.sendMessage(to: conversationId,
                                               recipientEmail: self!.otherUserEmail,
                                               name: name,
                                               newMessage: message) { success in
                if success { print("🟢 Successfully send location message") }
                else { print("🔴 Failed to send message") }
            }
        }
        navigationController?.pushViewController(vc, animated: true)
    }
    
    private func presentPhotoInputActionSheet() {
        let actionSheet = UIAlertController(title: "Attach Photo",
                                            message: "What would you like to attach photo from?",
                                            preferredStyle: .actionSheet)
        actionSheet.addAction(UIAlertAction(title: "Camera", style: .default, handler: { [weak self] _ in
            let picker = UIImagePickerController()
            picker.sourceType = .camera
            picker.delegate = self
            picker.allowsEditing = true
            self?.present(picker, animated: true)
        }))
        actionSheet.addAction(UIAlertAction(title: "Library", style: .default, handler: { [weak self] _ in
            let picker = UIImagePickerController()
            picker.sourceType = .photoLibrary
            picker.delegate = self
            picker.allowsEditing = true
            self?.present(picker, animated: true)
        }))
        actionSheet.addAction(UIAlertAction(title: "Cancle", style: .default, handler: { _ in
            actionSheet.dismiss(animated: true, completion: nil)
        }))
        
        present(actionSheet, animated: true)
    }
    
    private func presentVideoInputActionSheet() {
        let actionSheet = UIAlertController(title: "Attach Video",
                                            message: "What would you like to attach a video from?",
                                            preferredStyle: .actionSheet)
        actionSheet.addAction(UIAlertAction(title: "Camera", style: .default, handler: { [weak self] _ in
            let picker = UIImagePickerController()
            picker.sourceType = .camera
            picker.delegate = self
            picker.mediaTypes = ["public.movie"]
            picker.videoQuality = .typeMedium
            picker.allowsEditing = true
            self?.present(picker, animated: true)
        }))
        actionSheet.addAction(UIAlertAction(title: "Library", style: .default, handler: { [weak self] _ in
            let picker = UIImagePickerController()
            picker.sourceType = .photoLibrary
            picker.delegate = self
            picker.mediaTypes = ["public.movie"]
            picker.videoQuality = .typeMedium
            picker.allowsEditing = true
            self?.present(picker, animated: true)
        }))
        actionSheet.addAction(UIAlertAction(title: "Cancle", style: .default, handler: { _ in
            actionSheet.dismiss(animated: true, completion: nil)
        }))
        
        present(actionSheet, animated: true)
    }
    
    private func listeningForMessages(id: String, shouldScrollToBottom: Bool) {
        DatabaseManager.shared.getAllMessageForConversation(with: id) { [weak self] result in
            switch result {
            case .success(let messages):
                guard !messages.isEmpty else { return }
                self?.messages = messages
                DispatchQueue.main.async {
                    self?.messagesCollectionView.reloadDataAndKeepOffset()
                    if shouldScrollToBottom {
                        self?.messagesCollectionView.scrollToLastItem()
                    }
                }
            case .failure(let error): print("🔴 Failed to get messages: \(error)")
            }
        }
    }

}

// MARK: - UIImagePickerControllerDelegate, UINavigationControllerDelegate
extension ChatViewController: UIImagePickerControllerDelegate, UINavigationControllerDelegate {
    func imagePickerControllerDidCancel(_ picker: UIImagePickerController) {
        picker.dismiss(animated: true, completion: nil)
    }
    func imagePickerController(_ picker: UIImagePickerController, didFinishPickingMediaWithInfo info: [UIImagePickerController.InfoKey : Any]) {
        picker.dismiss(animated: true, completion: nil)
        
        
        guard let messageId = createMessageId(),
              let conversationId = conversationId,
              let name = self.title,
              let selfSender = self.selfSender else {
            return
        }
        let otherUserEmail = self.otherUserEmail
        
        if let image = info[.editedImage] as? UIImage, let imageData = image.jpegData(compressionQuality: 0.8) {
            let fileName = "photo_message_\(messageId).jpeg".replacingOccurrences(of: " ", with: "-")
            
            // Upload image
            StorageManager.shared.uploadMessagePhoto(with: imageData, fileName: fileName) { result in
                switch result {
                case .success(let urlString):
                    // Ready to send message
                    guard let url = URL(string: urlString),
                          let placeholder = UIImage(systemName: "plus") else {
                        return
                    }
                    
                    let media = Media(url: url,
                                      image: nil,
                                      placeholderImage: placeholder,
                                      size: .zero)
                    
                    let message = Message(sender: selfSender,
                                          messageId: messageId,
                                          sentDate: Date(),
                                          kind: .photo(media))
                    
                    DatabaseManager.shared.sendMessage(to: conversationId,
                                                       recipientEmail: otherUserEmail,
                                                       name: name,
                                                       newMessage: message) { success in
                        if success { print("🟢 Successfully send message") }
                        else { print("🔴 Failed to send message") }
                    }
                case .failure(let error): print("🔴 message photo upload error: \(error)")
                }
            }
        } else if let videoUrl = info[.mediaURL] as? URL {
            let fileName = "video_message_\(messageId).mov".replacingOccurrences(of: " ", with: "-")
            
            print(videoUrl)
            // Upload Video
            StorageManager.shared.uploadMessageVideo(with: videoUrl, fileName: fileName) { result in
                switch result {
                case .success(let urlString):
                    // Ready to send message
                    guard let url = URL(string: urlString),
                          let placeholder = UIImage(systemName: "plus") else {
                        return
                    }
                    
                    let media = Media(url: url,
                                      image: nil,
                                      placeholderImage: placeholder,
                                      size: .zero)
                    
                    let message = Message(sender: selfSender,
                                          messageId: messageId,
                                          sentDate: Date(),
                                          kind: .video(media))
                    
                    DatabaseManager.shared.sendMessage(to: conversationId,
                                                       recipientEmail: otherUserEmail,
                                                       name: name,
                                                       newMessage: message) { success in
                        if success { print("🟢 Successfully send message") }
                        else { print("🔴 Failed to send message") }
                    }
                case .failure(let error): print("🔴 message video upload error: \(error)")
                }
            }
        }
    }
}

// MARK: - InputBarAccessoryViewDelegate
extension ChatViewController: InputBarAccessoryViewDelegate {
    func inputBar(_ inputBar: InputBarAccessoryView, didPressSendButtonWith text: String) {
        guard !text.replacingOccurrences(of: " ", with: "").isEmpty,
              let messageId = createMessageId(),
              let selfSender = self.selfSender else {
            return
        }
        
        print("🟢 Sending text: \(text)")
        
        let message = Message(sender: selfSender,
                              messageId: messageId,
                              sentDate: Date(),
                              kind: .text(text))
        
        // Send message
        if isNewConversation {
            // Create conversation in database
            DatabaseManager.shared.createNewConversation(with: otherUserEmail, name: self.title ?? "User", firstMessage: message) { [weak self] success in
                if success {
                    print("🟢 Successfully send message: \(message)")
                    self?.isNewConversation = false
                } else { print("🔴 Failed to send") }
            }
        } else {
            // append to existing conversation data
            guard let conversationId = self.conversationId, let name = self.title else { return }
            DatabaseManager.shared.sendMessage(to: conversationId, recipientEmail: otherUserEmail, name: name, newMessage: message) { success in
                if success { print("🟢 Successfully send message: \(message)") }
                else { print("🔴 Failed to send") }
            }
        }
        
        inputBar.inputTextView.text = ""
    }
    
    private func createMessageId() -> String? {
        // date, otherUserEmail, senderEmail, random Int
        guard let currentUserEmail = UserDefaults.standard.value(forKey: "email") as? String else {
            return nil
        }
        let dateString = Self.dateFormatter.string(from: Date())
        let safeEmail = DatabaseManager.safeEmail(emailAddress: currentUserEmail)
        let newIdentifier = "\(otherUserEmail)_\(safeEmail)_\(dateString)"
        print("🟢 Created message id: \(newIdentifier)")
        return newIdentifier
    }
}

// MARK: -  MessagesDataSource, MessagesLayoutDelegate, MessagesDisplayDelegat
extension ChatViewController: MessagesDataSource, MessagesLayoutDelegate, MessagesDisplayDelegate {
    func currentSender() -> SenderType {
        if let sender = selfSender {
            return sender
        }
        fatalError("Self sender is nil, email should be cached")
    }
    
    func messageForItem(at indexPath: IndexPath, in messagesCollectionView: MessagesCollectionView) -> MessageType {
        return messages[indexPath.section]
    }
    
    func numberOfSections(in messagesCollectionView: MessagesCollectionView) -> Int {
        return messages.count
    }
    
    func configureMediaMessageImageView(_ imageView: UIImageView, for message: MessageType, at indexPath: IndexPath, in messagesCollectionView: MessagesCollectionView) {
        guard let message = message as? Message else {
            return
        }
        
        switch message.kind {
        case .photo(let media):
            guard let imageUrl = media.url else {
               return
            }
            imageView.sd_setImage(with: imageUrl, completed: nil)
        default:
            break
        }
    }
    
    func backgroundColor(for message: MessageType, at indexPath: IndexPath, in messagesCollectionView: MessagesCollectionView) -> UIColor {
        let sender = message.sender
        if sender.senderId == selfSender?.senderId {
            return .link
        }
        return .secondarySystemBackground
    }
    
    func configureAvatarView(_ avatarView: AvatarView, for message: MessageType, at indexPath: IndexPath, in messagesCollectionView: MessagesCollectionView) {
        
        let sender = message.sender
        
        if sender.senderId == selfSender?.senderId {
            if let currentUserImage = self.senderPhotoUrl {
                avatarView.sd_setImage(with: currentUserImage, completed: nil)
            } else {
                guard let email = UserDefaults.standard.value(forKey: "email") as? String else {
                    return
                }
                let safeEmail = DatabaseManager.safeEmail(emailAddress: email)
                let path = "images/\(safeEmail)_profile_picture.jpeg"
                
                // fetch url
                StorageManager.shared.downloadURL(for: path) { [weak self] result in
                    switch result {
                    case .success(let url):
                        self?.senderPhotoUrl = url
                        DispatchQueue.main.async {
                            avatarView.sd_setImage(with: url, completed: nil)
                        }
                    case .failure(let error):
                        print("\(error)")
                    }
                }
            }
        } else {
            // other user image
            if let otherUserPhotoUrl = self.otherUserPhotoUrl {
                avatarView.sd_setImage(with: otherUserPhotoUrl, completed: nil)
            } else {
                let path = "images/\(otherUserEmail)_profile_picture.jpeg"
                
                // fetch url
                StorageManager.shared.downloadURL(for: path) { [weak self] result in
                    switch result {
                    case .success(let url):
                        self?.otherUserPhotoUrl = url
                        DispatchQueue.main.async {
                            avatarView.sd_setImage(with: url, completed: nil)
                        }
                    case .failure(let error):
                        print("\(error)")
                    }
                }
            }
        }
    }
}

// MARK: - MessageCellDelegate
extension ChatViewController: MessageCellDelegate {
    func didTapMessage(in cell: MessageCollectionViewCell) {
        guard let indexPath = messagesCollectionView.indexPath(for: cell) else {
            return
        }
        let message = messages[indexPath.section]
        
        switch message.kind {
        case .location(let locationData):
            let coordinates = locationData.location.coordinate
            let vc = LocationPickerViewController(coordinates: coordinates)
            vc.title = "Location"
            self.navigationController?.pushViewController(vc, animated: true)
        default:
            break
        }
    }
    
    func didTapImage(in cell: MessageCollectionViewCell) {
        guard let indexPath = messagesCollectionView.indexPath(for: cell) else {
            return
        }
        let message = messages[indexPath.section]
        
        switch message.kind {
        case .photo(let media):
            guard let imageUrl = media.url else {
               return
            }
            let vc = PhotoViewerViewController(with: imageUrl)
            self.navigationController?.pushViewController(vc, animated: true)
        case .video(let media):
            guard let videoUrl = media.url else {
                return
            }
            
            let vc = AVPlayerViewController()
            vc.player = AVPlayer(url: videoUrl)
            vc.player?.play()
            present(vc, animated: true)
        default:
            break
        }
    }
}
