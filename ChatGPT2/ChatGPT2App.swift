//
//  ChatGPT2App.swift
//  ChatGPT2
//
//  Created by Ryan Whooley on 8/23/24.
//

import SwiftUI
import FirebaseCore
import FirebaseAuth
import Firebase
import Stripe

@main
struct ChatGPT2App: App {
    @StateObject private var appState = AppState()
    @StateObject private var healthKitManager = HealthKitManager()
    @StateObject private var bankViewModel = BankViewModel() // Add BankViewModel as a state object
    
    // Use UIApplicationDelegateAdaptor to create an AppDelegate in a SwiftUI app
    @UIApplicationDelegateAdaptor(AppDelegate.self) var appDelegate

    var body: some Scene {
        WindowGroup {
            if appState.isLoggedIn {
                MainTabView()
                    .environmentObject(appState)
                    .environmentObject(healthKitManager)
                    .environmentObject(bankViewModel) // Inject BankViewModel into the environment
            } else {
                LoginView()
                    .environmentObject(appState)
            }
        }
    }
}

// Custom AppDelegate class
class AppDelegate: NSObject, UIApplicationDelegate {
    func application(_ application: UIApplication,
                     didFinishLaunchingWithOptions launchOptions: [UIApplication.LaunchOptionsKey: Any]? = nil) -> Bool {
        // Initialize Firebase
        FirebaseApp.configure()
        
        // Initialize Stripe
        StripeAPI.defaultPublishableKey = "pk_test_51Prriv2NXGpM0jgV8MIO2aRaOKn35E01MGwIS6dXILnIOd2fg4i8d5aWx19vG3jUeQVUo8s8O4oAOENqfvq7CTMy00BIsZct3y"
        
        // Additional setup code can go here if needed
        
        return true
    }
    
    func application(_ app: UIApplication, open url: URL, options: [UIApplication.OpenURLOptionsKey : Any] = [:]) -> Bool {
        if url.scheme == "DemoApp" {
            if url.host == "refresh-stripe-onboarding" {
                // Handle refresh scenario
                // Probably want to restart the onboarding process
            } else if url.host == "return-from-stripe-onboarding" {
                // Handle return scenario
                // Probably want to check the account status again
            }
            return true
        }
        return false
    }
}
