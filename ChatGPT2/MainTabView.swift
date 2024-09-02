//
//  MainTabView.swift
//  ChatGPT2
//
//  Created by Ryan Whooley on 8/25/24.
//

import SwiftUI
import HealthKit

struct MainTabView: View {
    @State private var selectedTab = 0
    @State private var showingWorkoutTypeSelection = false
    @State private var showingWorkout = false
    @State private var showingProfile = false
    @StateObject private var workoutManager = WorkoutManager()
    @State private var selectedWorkoutType: HKWorkoutActivityType?
    @EnvironmentObject private var appState: AppState
    @EnvironmentObject private var healthKitManager: HealthKitManager
    
    var body: some View {
        NavigationView {
            TabView(selection: $selectedTab) {
                HomeView()
                    .tabItem {
                        Image(systemName: "house")
                        Text("Home")
                    }
                    .tag(0)
                
                BankView()
                    .tabItem {
                        Image(systemName: "banknote")
                        Text("Bank")
                    }
                    .tag(1)
                
                CommunityView()
                    .tabItem {
                        Image(systemName: "person.3")
                        Text("Community")
                    }
                    .tag(2)
                
                PerformanceView()
                    .tabItem {
                        Image(systemName: "chart.bar")
                        Text("Performance")
                    }
                    .tag(3)
            }
            .navigationBarTitle(getTitle(for: selectedTab), displayMode: .inline)
            .navigationBarItems(trailing: profileButton)
            .overlay(
                VStack {
                    Spacer()
                    Button(action: {
                        showingWorkoutTypeSelection = true
                    }) {
                        Image(systemName: "plus")
                            .font(.title)
                            .foregroundColor(.black)
                            .frame(width: 45, height: 45)
                            .background(Color.secondary)
                            .clipShape(Circle())
                            .shadow(radius: 4)
                    }
                    .padding(.bottom, 30)
                }
            )
        }
        .sheet(isPresented: $showingWorkoutTypeSelection) {
            WorkoutTypeSelectionView(isPresented: $showingWorkoutTypeSelection, selectedWorkoutType: $selectedWorkoutType)
        }
        .fullScreenCover(isPresented: $showingWorkout) {
            WorkoutView(workoutManager: workoutManager, isPresented: $showingWorkout)
        }
        .sheet(isPresented: $showingProfile) {
            ProfileView()
        }
        .onChange(of: selectedWorkoutType) { oldValue, newValue in
            if let workoutType = newValue {
                workoutManager.workoutType = workoutType
                showingWorkout = true
            }
        }
    }
    
    private var profileButton: some View {
        Button(action: {
            showingProfile = true
        }) {
            Image(systemName: "person.crop.circle")
                .font(.system(size: 25))
                .foregroundColor(.gray)
        }
    }
    
    private func getTitle(for tab: Int) -> String {
        switch tab {
        case 0:
            return "Home"
        case 1:
            return "Bank"
        case 2:
            return "Community"
        case 3:
            return "Performance"
        default:
            return ""
        }
    }
}

#Preview {
    MainTabView()
        .environmentObject(HealthKitManager())
}


