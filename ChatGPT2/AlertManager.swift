//
//  AlertManager.swift
//  ChatGPT2
//
//  Created by Ryan Whooley on 9/13/24.
//

import SwiftUI

class AlertManager: ObservableObject {
    @Published var showAlert = false
    @Published var alertTitle = ""
    @Published var alertMessage = ""
    
    func showAlert(title: String, message: String) {
        alertTitle = title
        alertMessage = message
        showAlert = true
    }
}
