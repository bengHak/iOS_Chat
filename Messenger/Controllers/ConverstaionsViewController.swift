//
//  ViewController.swift
//  Messenger
//
//  Created by byunghak on 2021/08/21.
//

import UIKit
import FirebaseAuth

class ConverstaionsViewController: UIViewController {
    
    private let tableView: UITableView = {
        let table = UITableView()
//        table.register(UITableViewCell.self))
        return table
    }()

    override func viewDidLoad() {
        super.viewDidLoad()
        view.backgroundColor = .white
    }

    override func viewDidAppear(_ animated: Bool) {
        super.viewDidAppear(animated)
        
        validateAuth()
    }
    
    private func validateAuth() {
        if FirebaseAuth.Auth.auth().currentUser == nil {
            let vc = LoginViewController()
            let nav = UINavigationController(rootViewController: vc)
            nav.modalPresentationStyle = .fullScreen
            present(nav, animated: false)
        }
    }

}

