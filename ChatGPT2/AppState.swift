//
//  AppState.swift
//  ChatGPT2
//
//  Created by Ryan Whooley on 8/26/24.
//

import SwiftUI
import FirebaseAuth

class AppState: ObservableObject {
    @Published var isLoggedIn: Bool = false
    
    init() {
        // Check if user is already logged in
        if Auth.auth().currentUser != nil {
            isLoggedIn = true
        }
        
        // Listen for authentication state changes
        Auth.auth().addStateDidChangeListener { [weak self] _, user in
            DispatchQueue.main.async {
                self?.isLoggedIn = user != nil
            }
        }
    }
}
