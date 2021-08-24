//
//  NewConversationViewController.swift
//  Messenger
//
//  Created by byunghak on 2021/08/21.
//

import UIKit
import JGProgressHUD

class NewConversationViewController: UIViewController {
    
    public var completion: ((SearchResult) -> (Void))?
    
    private let spinner = JGProgressHUD(style: .dark)
    
    private var users = [[String:String]]()
    
    private var results = [SearchResult]()
    
    private var hasFetched = false
    
    private let searchBar: UISearchBar = {
        let searchBar = UISearchBar()
        searchBar.placeholder = "Search for Users..."
        return searchBar
    }()
    
    private let tableView: UITableView = {
        let table = UITableView()
        table.isHidden = true
        table.register(NewConversationCell.self, forCellReuseIdentifier: NewConversationCell.identifier)
        return table
    }()
    
    private let noResultsLabel: UILabel = {
        let label = UILabel()
        label.text = "No Results"
        label.textAlignment = .center
        label.textColor = .lightGray
        label.font = .systemFont(ofSize: 21, weight: .medium)
        return label
    }()
    
// MARK: - Lifecycle
    override func viewDidLoad() {
        super.viewDidLoad()
        view.addSubview(noResultsLabel)
        view.addSubview(tableView)
        
        tableView.delegate = self
        tableView.dataSource = self
        
        searchBar.delegate = self
        
        view.backgroundColor = .white
        navigationController?.navigationBar.topItem?.titleView = searchBar
        navigationItem.rightBarButtonItem = UIBarButtonItem(title: "Cancle",
                                                            style: .done,
                                                            target: self,
                                                            action: #selector(dismissSelf))
        searchBar.becomeFirstResponder()
    }
    
    override func viewDidLayoutSubviews() {
        super.viewDidLayoutSubviews()
        tableView.frame = view.bounds
        noResultsLabel.frame = CGRect(x: view.width/4,
                                      y: (view.height-200)/2,
                                      width: view.width/2,
                                      height: 200)
    }
    
    @objc private func dismissSelf() {
        dismiss(animated: true, completion: nil)
    }
    
}

// MARK: - UITableViewDelegate, UITableViewDataSource
extension NewConversationViewController: UITableViewDelegate, UITableViewDataSource {
    func tableView(_ tableView: UITableView, numberOfRowsInSection section: Int) -> Int {
        return results.count
    }
    func tableView(_ tableView: UITableView, cellForRowAt indexPath: IndexPath) -> UITableViewCell {
        let model = results[indexPath.row]
        let cell = tableView.dequeueReusableCell(withIdentifier: NewConversationCell.identifier, for: indexPath) as! NewConversationCell
        cell.configure(with: model)
        return cell
    }
    func tableView(_ tableView: UITableView, didSelectRowAt indexPath: IndexPath) {
        tableView.deselectRow(at: indexPath, animated: true)
        // start conversation
        let targetUserData = results[indexPath.row]
        self.dismiss(animated: true) { [weak self] in
            self?.completion?(targetUserData)
        }
    }
    func tableView(_ tableView: UITableView, heightForRowAt indexPath: IndexPath) -> CGFloat {
        90
    }
}

// MARK: - UISearchBarDelegate
extension NewConversationViewController: UISearchBarDelegate {
    
    func searchBarSearchButtonClicked(_ searchBar: UISearchBar) {
        guard let text = searchBar.text,
              !text.replacingOccurrences(of: " ", with: " ").isEmpty else {
            return
        }
        
        searchBar.resignFirstResponder()
        results.removeAll()
        spinner.show(in: view)
        
        self.searchUsers(query: text)
    }
    
    func searchUsers(query: String) {
        // check if array has firebase results
        if hasFetched {
            // if it does: filter
            filterUsers(with: query)
        } else {
            // if not: fetch then filter
            DatabaseManager.shared.getAllUsers { [weak self] result in
                switch result {
                case .success(let usersCollection):
                    self?.hasFetched = true
                    self?.users = usersCollection
                    self?.filterUsers(with: query)
                case .failure(let error):
                    print("🔴 Failed to get users: \(error)")
                }
            }
        }
        // if not, fetch then filter
    }
    
    func filterUsers(with term: String) {
        // update UI: either who resulst or show no results label
        guard let currentEmail = UserDefaults.standard.value(forKey: "email") as? String,
              hasFetched else {
            return
        }
        let safeEmail = DatabaseManager.safeEmail(emailAddress: currentEmail)
    
        self.spinner.dismiss()
        
        let results:[SearchResult] = self.users.filter {
            guard let email = $0["email"], email != safeEmail else { return false }
            guard let name = $0["name"]?.lowercased() else { return false }
            return name.hasPrefix(term.lowercased())
        }.compactMap({
            guard let email = $0["email"], email != safeEmail else { return nil }
            guard let name = $0["name"]?.lowercased() else { return nil }
            return SearchResult(name: name, email: email)
        })
        
        self.results = results
        
        updateUI()
    }
    
    func updateUI() {
        if results.isEmpty {
            self.noResultsLabel.isHidden = false
            self.tableView.isHidden = true
        } else {
            self.noResultsLabel.isHidden = true
            self.tableView.isHidden = false
            self.tableView.reloadData()
        }
    }
}


struct SearchResult {
    let name: String
    let email: String
}
