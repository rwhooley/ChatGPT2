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
            Group {
                if isLoading {
                    ProgressView()
                } else if let user = user {
                    userProfileContent(user: user)
                } else if let errorMessage = errorMessage {
                    Text("Error: \(errorMessage)")
                }
            }
            .navigationTitle("Profile")
            .alert(isPresented: $showingHealthKitError) {
                Alert(title: Text("HealthKit Error"), message: Text(healthKitErrorMessage), dismissButton: .default(Text("OK")))
            }
            .alert(isPresented: $showingLogoutAlert) {
                Alert(
                    title: Text("Log Out"),
                    message: Text("Are you sure you want to log out?"),
                    primaryButton: .destructive(Text("Log Out")) {
                        logOut()
                    },
                    secondaryButton: .cancel()
                )
            }
        }
        .onAppear(perform: fetchUserDataAndCheckHealthKitStatus)
    }

    private func userProfileContent(user: AppUser) -> some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 20) {
                Text("Name: \(user.name)")
                    .font(.headline)
                Text("Email: \(user.email)")
                    .font(.headline)
                Text("Member Since: \(formatDate(user.memberSince))")
                    .font(.subheadline)

                if healthKitManager.isAuthorized {
                    Button(action: fetchLatestWorkouts) {
                        Text("Refresh Health Data")
                            .padding()
                            .background(Color.blue)
                            .foregroundColor(.white)
                            .cornerRadius(10)
                    }
                } else {
                    Button(action: connectToHealthKit) {
                        Text("Connect Apple Health")
                            .padding()
                            .background(Color.blue)
                            .foregroundColor(.white)
                            .cornerRadius(10)
                    }
                }

                if !latestWorkouts.isEmpty {
                    VStack(alignment: .leading, spacing: 10) {
                        Text("Latest Workouts:")
                            .font(.headline)
                        ForEach(latestWorkouts) { workout in
                            HStack {
                                Text(HKWorkoutActivityType.name(for: workout.type))
                                Spacer()
                                Text(formatDuration(workout.duration))
                            }
                            .padding(.vertical, 5)
                        }
                    }
                    .padding()
                    .background(Color.gray.opacity(0.1))
                    .cornerRadius(10)
                }

                Spacer()

                Button(action: {
                    showingLogoutAlert = true
                }) {
                    Text("Log Out")
                        .foregroundColor(.white)
                        .padding()
                        .frame(maxWidth: .infinity)
                        .background(Color.red)
                        .cornerRadius(10)
                }
            }
            .padding()
        }
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
                healthKitErrorMessage = error.localizedDescription
                showingHealthKitError = true
            } else {
                self.latestWorkouts = Array(workouts.prefix(5)) // Take only the first 5 workouts
            }
        }
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
                let name = data["name"] as? String ?? ""
                let email = data["email"] as? String ?? ""
                let memberSince = (data["memberSince"] as? Timestamp)?.dateValue() ?? Date()
                self.user = AppUser(id: document.documentID, name: name, email: email, memberSince: memberSince)
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

struct ProfileView_Previews: PreviewProvider {
    static var previews: some View {
        ProfileView()
            .environmentObject(AppState())
            .environmentObject(HealthKitManager())
    }
}

#Preview {
    ProfileView()
        .environmentObject(HealthKitManager())
}
