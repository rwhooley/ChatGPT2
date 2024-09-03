//
//  CommunityView.swift
//  ChatGPT2
//
//  Created by Ryan Whooley on 8/25/24.
//

import SwiftUI
import FirebaseFirestore
import FirebaseAuth

struct CommunityView: View {
    @StateObject private var viewModel = CommunityViewModel()
    
    var body: some View {
        NavigationView {
            List {
                Section(header: Text("Add Friend")) {
                    HStack {
                        TextField("Enter friend's email", text: $viewModel.newFriendEmail)
                            .textFieldStyle(RoundedBorderTextFieldStyle())
                        Button("Add") {
                            viewModel.sendFriendRequest()
                        }
                    }
                }
                
                Section(header: Text("Friend Requests")) {
                    if viewModel.friendRequests.isEmpty {
                        Text("No pending friend requests")
                            .foregroundColor(.gray)
                    } else {
                        ForEach(viewModel.friendRequests) { request in
                            HStack {
                                Text(request.senderEmail)
                                Spacer()
                                Button("Accept") {
                                    viewModel.acceptFriendRequest(request)
                                }
                                Button("Decline") {
                                    viewModel.declineFriendRequest(request)
                                }
                            }
                        }
                    }
                }
                
                Section(header: Text("Friends' Workouts")) {
                    if viewModel.friendWorkouts.isEmpty {
                        Text("No friend workouts to display")
                            .foregroundColor(.gray)
                    } else {
                        ForEach(viewModel.friendWorkouts) { workout in
                            FriendWorkoutRow(workout: workout)
                        }
                    }
                }
            }
            .listStyle(GroupedListStyle())
        }
        .onAppear {
            viewModel.loadData()
        }
        .alert(item: $viewModel.alertItem) { alertItem in
            Alert(title: Text(alertItem.title),
                  message: Text(alertItem.message),
                  dismissButton: .default(Text("OK")))
        }
    }
}

class CommunityViewModel: ObservableObject {
    @Published var newFriendEmail = ""
    @Published var friendRequests: [FriendRequest] = []
    @Published var friends: [User] = []
    @Published var friendWorkouts: [FriendWorkout] = []
    @Published var alertItem: AlertItem?
    
    private var db = Firestore.firestore()
    
    func sendFriendRequest() {
        guard let currentUser = Auth.auth().currentUser else {
            alertItem = AlertItem(title: "Error", message: "You must be logged in to send friend requests")
            return
        }
        
        db.collection("users").whereField("email", isEqualTo: newFriendEmail).getDocuments { [weak self] (querySnapshot, error) in
            guard let self = self else { return }
            
            if let error = error {
                self.alertItem = AlertItem(title: "Error", message: error.localizedDescription)
            } else if let documents = querySnapshot?.documents, !documents.isEmpty {
                let friendID = documents[0].documentID
                let friendRequest = FriendRequest(
                    id: UUID().uuidString,
                    senderID: currentUser.uid,
                    receiverID: friendID,
                    status: "pending",
                    senderEmail: currentUser.email ?? "Unknown"
                )
                self.db.collection("friendRequests").addDocument(data: friendRequest.dictionary)
                self.alertItem = AlertItem(title: "Success", message: "Friend request sent!")
                self.newFriendEmail = ""
            } else {
                self.alertItem = AlertItem(title: "Error", message: "User not found")
            }
        }
    }
    
    func acceptFriendRequest(_ request: FriendRequest) {
        db.collection("friendRequests").document(request.id).updateData(["status": "accepted"])
        // Add logic to update friends list for both users
        loadData()
    }
    
    func declineFriendRequest(_ request: FriendRequest) {
        db.collection("friendRequests").document(request.id).delete()
        loadData()
    }
    
    func loadData() {
        loadFriendRequests()
        loadFriends()
        loadFriendWorkouts()
    }
    
    private func loadFriendRequests() {
        guard let currentUserID = Auth.auth().currentUser?.uid else { return }
        
        db.collection("friendRequests")
            .whereField("receiverID", isEqualTo: currentUserID)
            .whereField("status", isEqualTo: "pending")
            .addSnapshotListener { [weak self] querySnapshot, error in
                guard let documents = querySnapshot?.documents else {
                    print("Error fetching friend requests: \(error?.localizedDescription ?? "Unknown error")")
                    return
                }
                self?.friendRequests = documents.compactMap { FriendRequest(dictionary: $0.data()) }
            }
    }

    
    private func loadFriends() {
        // Implement friend loading logic
        // For example:
        guard let currentUserID = Auth.auth().currentUser?.uid else { return }
        
        db.collection("friends")
            .whereField("userIDs", arrayContains: currentUserID)
            .getDocuments { [weak self] querySnapshot, error in
                guard let documents = querySnapshot?.documents else {
                    print("Error fetching friends: \(error?.localizedDescription ?? "Unknown error")")
                    return
                }
                self?.friends = documents.compactMap { document -> User? in
                    let data = document.data()
                    let friendID = (data["userIDs"] as? [String])?.first { $0 != currentUserID } ?? ""
                    return User(id: friendID, name: data["name"] as? String ?? "", email: data["email"] as? String ?? "")
                }
            }
    }
    
    private func loadFriendWorkouts() {
        // Implement friend workout loading logic
        // For example:
        guard let currentUserID = Auth.auth().currentUser?.uid else { return }
        
        db.collection("workouts")
            .whereField("userID", isNotEqualTo: currentUserID)  // Assuming workouts have a userID field
            .order(by: "date", descending: true)
            .limit(to: 20)  // Limit to last 20 workouts for performance
            .getDocuments { [weak self] querySnapshot, error in
                guard let documents = querySnapshot?.documents else {
                    print("Error fetching friend workouts: \(error?.localizedDescription ?? "Unknown error")")
                    return
                }
                self?.friendWorkouts = documents.compactMap { document -> FriendWorkout? in
                    let data = document.data()
                    return FriendWorkout(
                        id: document.documentID,
                        friendName: data["userName"] as? String ?? "Unknown",
                        workoutType: data["workoutType"] as? String ?? "Unknown",
                        duration: data["duration"] as? TimeInterval ?? 0,
                        distance: data["distance"] as? Double ?? 0,
                        date: (data["date"] as? Timestamp)?.dateValue() ?? Date()
                    )
                }
            }
    }
}

struct FriendRequest: Identifiable {
    let id: String
    let senderID: String
    let receiverID: String
    let status: String
    let senderEmail: String
    
    var dictionary: [String: Any] {
        return [
            "id": id,
            "senderID": senderID,
            "receiverID": receiverID,
            "status": status,
            "senderEmail": senderEmail
        ]
    }
    
    init(id: String, senderID: String, receiverID: String, status: String, senderEmail: String) {
        self.id = id
        self.senderID = senderID
        self.receiverID = receiverID
        self.status = status
        self.senderEmail = senderEmail
    }
    
    init?(dictionary: [String: Any]) {
        guard let id = dictionary["id"] as? String,
              let senderID = dictionary["senderID"] as? String,
              let receiverID = dictionary["receiverID"] as? String,
              let status = dictionary["status"] as? String,
              let senderEmail = dictionary["senderEmail"] as? String
        else { return nil }
        
        self.id = id
        self.senderID = senderID
        self.receiverID = receiverID
        self.status = status
        self.senderEmail = senderEmail
    }
}

struct User: Identifiable {
    let id: String
    let name: String
    let email: String
}

struct FriendWorkout: Identifiable {
    let id: String
    let friendName: String
    let workoutType: String
    let duration: TimeInterval
    let distance: Double
    let date: Date
}

struct FriendWorkoutRow: View {
    let workout: FriendWorkout
    
    var body: some View {
        VStack(alignment: .leading) {
            Text("\(workout.friendName) - \(workout.workoutType)")
                .font(.headline)
            Text("Duration: \(formatDuration(workout.duration))")
            Text("Distance: \(String(format: "%.2f", workout.distance)) km")
            Text("Date: \(formatDate(workout.date))")
        }
        .padding()
        .background(Color.gray.opacity(0.1))
        .cornerRadius(10)
    }
    
    private func formatDuration(_ duration: TimeInterval) -> String {
        let formatter = DateComponentsFormatter()
        formatter.allowedUnits = [.hour, .minute, .second]
        formatter.unitsStyle = .abbreviated
        return formatter.string(from: duration) ?? ""
    }
    
    private func formatDate(_ date: Date) -> String {
        let formatter = DateFormatter()
        formatter.dateStyle = .medium
        formatter.timeStyle = .short
        return formatter.string(from: date)
    }
}



struct AlertItem: Identifiable {
    let id = UUID()
    let title: String
    let message: String
}

#Preview {
    CommunityView()
}
