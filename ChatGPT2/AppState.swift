//
//  AppState.swift
//  ChatGPT2
//
//  Created by Ryan Whooley on 8/26/24.
//

import SwiftUI
import FirebaseAuth
import FirebaseFirestore

class AppState: ObservableObject {
    @Published var isLoggedIn: Bool = false
    @Published var totalBalance: Double = 0.0  // Total balance property
    
    init() {
        // Check if user is already logged in
        if Auth.auth().currentUser != nil {
            isLoggedIn = true
            fetchTotalBalance()  // Fetch the balance when the user is already logged in
        }
        
        // Listen for authentication state changes
        _ = Auth.auth().addStateDidChangeListener { [weak self] _, user in
            DispatchQueue.main.async {
                self?.isLoggedIn = user != nil
                if user != nil {
                    self?.fetchTotalBalance()  // Fetch the balance whenever the user logs in
                } else {
                    self?.totalBalance = 0.0  // Reset balance on logout
                }
            }
        }
    }
    
    // Function to fetch the total balance from Firebase
    func fetchTotalBalance() {
        guard let userId = Auth.auth().currentUser?.uid else {
            print("User not logged in")
            return
        }

        let db = Firestore.firestore()
        db.collection("users").document(userId).getDocument { [weak self] document, error in
            if let document = document, document.exists {
                if let balance = document.data()?["totalBalance"] as? Double {
                    DispatchQueue.main.async {
                        self?.totalBalance = balance  // Set total balance from Firestore
                    }
                }
            } else {
                print("Error fetching document: \(error?.localizedDescription ?? "Unknown error")")
            }
        }
    }
}
