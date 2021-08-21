//
//  AppDelegate.swift
//  Messenger
//
//  Created by byunghak on 2021/08/21.
//

import UIKit
import Firebase
import FBSDKCoreKit
import GoogleSignIn

@UIApplicationMain
class AppDelegate: UIResponder, UIApplicationDelegate, GIDSignInDelegate {
    
    func application(
        _ application: UIApplication,
        didFinishLaunchingWithOptions launchOptions: [UIApplication.LaunchOptionsKey: Any]?
    ) -> Bool {
        FirebaseApp.configure()
          
        ApplicationDelegate.shared.application(
            application,
            didFinishLaunchingWithOptions: launchOptions
        )
        
        GIDSignIn.sharedInstance()?.clientID = FirebaseApp.app()?.options.clientID
        GIDSignIn.sharedInstance()?.delegate = self

        return true
    }
          
    func application(
        _ app: UIApplication,
        open url: URL,
        options: [UIApplication.OpenURLOptionsKey : Any] = [:]
    ) -> Bool {

        ApplicationDelegate.shared.application(
            app,
            open: url,
            sourceApplication: options[UIApplication.OpenURLOptionsKey.sourceApplication] as? String,
            annotation: options[UIApplication.OpenURLOptionsKey.annotation]
        )
        
        return GIDSignIn.sharedInstance().handle(url)
    }
    
    func sign(_ signIn: GIDSignIn!, didSignInFor user: GIDGoogleUser!, withError error: Error!) {
        guard error == nil else {
            print("🔴 Failed to sign in with Google: \(String(describing: error))")
            return
        }
        
        guard let email = user.profile.email,
              let firstName = user.profile.givenName,
              let lastName = user.profile.familyName else { return }
        
        print("🟢 Did sign in with Google: \(String(describing: user))")
        
        DatabaseManager.shared.userExtists(with: email, completion: { exists in
            if !exists {
                // insert to database
                DatabaseManager.shared.insertUser(with: ChatAppUser(firstName: firstName, lastName: lastName, emailAddress: email))
            }
        })
        
        guard let autentication = user.authentication else {
            print("🔴 Missing auth object off of google user")
            return
        }
        let credential = GoogleAuthProvider.credential(withIDToken: autentication.idToken,
                                                       accessToken: autentication.accessToken)
        
        FirebaseAuth.Auth.auth().signIn(with: credential, completion: { authResult, error in
            guard authResult != nil, error == nil else {
                print("🔴 Failed to log in with google credential")
                return
            }
            
            print("🟢 Successfully signed in with Google credential.")
            NotificationCenter.default.post(name: .didLoginNotification, object: nil)
        })
    }

    func sign(_ signIn: GIDSignIn!, didDisconnectWith user: GIDGoogleUser!, withError error: Error!) {
        print("🟢 Google user was disconnected")
    }
}
    
