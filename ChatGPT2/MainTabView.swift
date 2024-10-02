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
    @State private var showingHelp = false  // State to show the instructional screens on-demand
    @StateObject private var workoutManager = WorkoutManager()
    @State private var selectedWorkoutType: HKWorkoutActivityType?
    @EnvironmentObject private var appState: AppState
    @EnvironmentObject private var healthKitManager: HealthKitManager
    @State private var showInstructionalScreens = false  // State to control showing instructional screens on login

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
            .navigationBarItems(
                leading: profileButton,
                trailing: HStack {
                    helpButton // Adds the help button to the navigation bar
                    balanceButton
                }
            )
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
        .fullScreenCover(isPresented: $showInstructionalScreens) {
            InstructionalScreensView(showInstructionalScreens: $showInstructionalScreens)
        }
        .fullScreenCover(isPresented: $showingHelp) {  // Show instructional screens on '?' button press
            InstructionalScreensView(showInstructionalScreens: $showingHelp)
        }
        .fullScreenCover(isPresented: $showingWorkout) {
            WorkoutView(workoutManager: workoutManager, isPresented: $showingWorkout)
        }
        .sheet(isPresented: $showingProfile) {
            ProfileView()
        }
        .onChange(of: selectedWorkoutType) {
            if let workoutType = selectedWorkoutType {
                workoutManager.startWorkout(workoutType: workoutType)
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
    
    private var balanceButton: some View {
        Text("$\(appState.totalBalance, specifier: "%.2f")")
            .font(.system(size: 16, weight: .bold))
            .padding(.horizontal)
            .background(Color.gray.opacity(0.2))
            .cornerRadius(8)
    }

    // Help button to manually trigger the instructional screens
    private var helpButton: some View {
        Button(action: {
            showingHelp = true  // Show instructional screens when '?' is pressed
        }) {
            Image(systemName: "questionmark.circle")
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
        .environmentObject(AppState())
}
