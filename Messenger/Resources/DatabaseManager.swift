//
//  DatabaseManager.swift
//  Messenger
//
//  Created by byunghak on 2021/08/21.
//

import Foundation
import FirebaseDatabase

final class DatabaseManager {

    // Singleton
    static let shared = DatabaseManager()
    
    // private let database = Database.database().reference()
    // region이 달라서 직접 설정해줘야한다
    private let database = Database.database(url: "https://messenger-96e06-default-rtdb.asia-southeast1.firebasedatabase.app/").reference()
}


// MARK: Account Management
extension DatabaseManager {
    
    public func userExtists(with email: String, completion: @escaping ((Bool) -> Void)) {
        database.child(email).observeSingleEvent(of: .value, with: { snapshot in
            guard snapshot.value as? String != nil else {
                completion(false)
                return
            }
            completion(true)
        })
    }
    
    /// Inserts new user to database
    public func insertUser(with user: ChatAppUser) {
        database.child(user.emailAddress).setValue([
            "first_name": user.firstName,
            "last_name": user.lastName
        ])
    }
}


struct ChatAppUser {
    let firstName: String
    let lastName: String
    let emailAddress: String
//    let profilePictureUrl: String
}
