//
//  User.swift
//  ChatGPT2
//
//  Created by Ryan Whooley on 8/25/24.
//

import Foundation

struct AppUser: Identifiable {
    let id: String
    let name: String
    let email: String
    let memberSince: Date
}
