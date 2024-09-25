//
//  ContentView.swift
//  ChatGPT2
//
//  Created by Ryan Whooley on 8/23/24.
//

import SwiftUI

struct ContentView: View {
    @EnvironmentObject var alertManager: AlertManager
    
    
    var body: some View {
        TabView {
            HomeView()
                .tabItem {
                    Label("Home", systemImage: "house")
                }
            
            PerformanceView()
                .tabItem {
                    Label("Performance", systemImage: "chart.bar")
                }
            
            ProfileView()
                .tabItem {
                    Label("Profile", systemImage: "person")
                }
                .alert(isPresented: $alertManager.showAlert) {
                            Alert(
                                title: Text(alertManager.alertTitle),
                                message: Text(alertManager.alertMessage),
                                dismissButton: .default(Text("OK"))
                            )
                        }
        }
        
    }
}
    
