//
//  ContentView.swift
//  ChatGPT2
//
//  Created by Ryan Whooley on 8/23/24.
//

import SwiftUI

struct ContentView: View {
   
    
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
        }
        
    }
}
    
