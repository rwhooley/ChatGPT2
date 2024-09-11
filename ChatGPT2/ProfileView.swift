//
//  ProfileView.swift
//  ChatGPT2
//
//  Created by Ryan Whooley on 8/25/24.
//

//
//  ProfileView.swift
//  ChatGPT2
//
//  Created by Ryan Whooley on 8/25/24.
//

import SwiftUI
import FirebaseFirestore
import FirebaseAuth
import HealthKit

struct ProfileView: View {
    @EnvironmentObject private var appState: AppState
    @EnvironmentObject private var healthKitManager: HealthKitManager
    @State private var user: AppUser?
    @State private var isLoading = true
    @State private var errorMessage: String?
    @State private var latestWorkouts: [DetailedWorkout] = []
    @State private var showingHealthKitError = false
    @State private var healthKitErrorMessage = ""
    @State private var showingLogoutAlert = false

    var body: some View {
        NavigationView {
            VStack {
                if isLoading {
                    ProgressView()
                } else if let user = user {
                    userProfileContent(user: user)
                } else if let errorMessage = errorMessage {
                    Text("Error: \(errorMessage)")
                }
            }
            .navigationTitle("Profile")
            .alert("HealthKit Error", isPresented: $showingHealthKitError) {
                Button("OK", role: .cancel) { }
            } message: {
                Text(healthKitErrorMessage)
            }
            .alert("Log Out", isPresented: $showingLogoutAlert) {
                Button("Log Out", role: .destructive, action: logOut)
                Button("Cancel", role: .cancel) { }
            } message: {
                Text("Are you sure you want to log out?")
            }
        }
        .onAppear(perform: fetchUserDataAndCheckHealthKitStatus)
    }

    private func userProfileContent(user: AppUser) -> some View {
        VStack {
            VStack(alignment: .leading, spacing: 10) {
                // Aligning text to the left
                Text("Name: \(user.firstName) \(user.lastName)")
                    .font(.body)
                    .padding()

                Text("Email: \(user.email)")
                    .font(.body)
                    .padding()

//                Text("Member Since: \(formatDate(user.memberSince))")
//                    .font(.body)
//                    .padding()
            }
            .frame(maxWidth: .infinity, alignment: .leading) // Align left with full width

            Spacer()

            // Buttons at the bottom
            VStack(spacing: 20) {
                if healthKitManager.isAuthorized {
                    Button(action: fetchLatestWorkouts) {
                        Text("Refresh Health Data")
                            .padding()
                            .frame(maxWidth: .infinity)
                            .background(Color.blue)
                            .foregroundColor(.white)
                            .cornerRadius(10)
                    }

                    Button(action: resetSyncDateAndFetchAllWorkouts) {
                        Text("Reset Sync Date and Fetch All Workouts")
                            .padding()
                            .frame(maxWidth: .infinity)
                            .background(Color.green)
                            .foregroundColor(.white)
                            .cornerRadius(10)
                    }
                } else {
                    Button(action: connectToHealthKit) {
                        Text("Connect Apple Health")
                            .padding()
                            .frame(maxWidth: .infinity)
                            .background(Color.blue)
                            .foregroundColor(.white)
                            .cornerRadius(10)
                    }
                }

                // Log out button
                Button(action: { showingLogoutAlert = true }) {
                    Text("Log Out")
                        .foregroundColor(.white)
                        .padding()
                        .frame(maxWidth: .infinity)
                        .background(Color.red)
                        .cornerRadius(10)
                }
            }
            .padding(.bottom, 20)
            .frame(maxWidth: .infinity)
        }
        .padding()
    }

    private func connectToHealthKit() {
        healthKitManager.requestFullAuthorization { success, error in
            if success {
                print("HealthKit authorization successful")
                fetchLatestWorkouts()
            } else {
                healthKitErrorMessage = error?.localizedDescription ?? "Unknown error occurred"
                showingHealthKitError = true
            }
        }
    }

    private func fetchLatestWorkouts() {
        healthKitManager.fetchAllDetailedWorkouts { workouts, error in
            if let error = error {
                print("Error fetching workouts: \(error)")
                self.healthKitErrorMessage = error.localizedDescription
                self.showingHealthKitError = true
            } else {
                self.latestWorkouts = Array(workouts.prefix(5)) // Take only the first 5 workouts
                print("Fetched \(workouts.count) workouts")
            }
        }
    }

    private func resetSyncDateAndFetchAllWorkouts() {
        healthKitManager.resetLastSyncDate()
        fetchLatestWorkouts()
    }

    private func fetchUserDataAndCheckHealthKitStatus() {
        fetchUserData()
        healthKitManager.checkAuthorizationStatus()
        if healthKitManager.isAuthorized {
            fetchLatestWorkouts()
        }
    }

    private func fetchUserData() {
        guard let userId = Auth.auth().currentUser?.uid else {
            self.errorMessage = "No user logged in"
            self.isLoading = false
            return
        }

        let db = Firestore.firestore()
        db.collection("users").document(userId).getDocument { (document, error) in
            self.isLoading = false
            if let error = error {
                self.errorMessage = error.localizedDescription
            } else if let document = document, document.exists, let data = document.data() {
                let firstName = data["firstName"] as? String ?? ""
                let lastName = data["lastName"] as? String ?? ""
                let email = data["email"] as? String ?? ""
                let memberSince = (data["memberSince"] as? Timestamp)?.dateValue() ?? Date()
                self.user = AppUser(id: document.documentID, firstName: firstName, lastName: lastName, email: email, memberSince: memberSince)
            } else {
                self.errorMessage = "User document does not exist or is empty"
            }
        }
    }

    private func logOut() {
        do {
            try Auth.auth().signOut()
            appState.isLoggedIn = false
        } catch let signOutError as NSError {
            print("Error signing out: %@", signOutError)
        }
    }

    private func formatDate(_ date: Date) -> String {
        let formatter = DateFormatter()
        formatter.dateStyle = .medium
        formatter.timeStyle = .none
        return formatter.string(from: date)
    }

    private func formatDuration(_ duration: TimeInterval) -> String {
        let formatter = DateComponentsFormatter()
        formatter.allowedUnits = [.hour, .minute, .second]
        formatter.unitsStyle = .abbreviated
        return formatter.string(from: duration) ?? ""
    }
}

#Preview {
    ProfileView()
        .environmentObject(AppState())
        .environmentObject(HealthKitManager())
}


