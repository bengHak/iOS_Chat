//
//  ProfileViewModel.swift
//  Messenger
//
//  Created by byunghak on 2021/08/28.
//

import Foundation

enum ProfileViewModelType {
    case info, logout
}

struct ProfileViewModel {
    let viewModelType: ProfileViewModelType
    let title: String
    let handler: (() -> Void)?
}
