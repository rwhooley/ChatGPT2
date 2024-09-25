//
//  CommunityView.swift
//  ChatGPT2
//
//  Created by Ryan Whooley on 8/25/24.
//

import SwiftUI
import FirebaseFirestore
import FirebaseAuth
import Foundation
import HealthKit

struct CommunityView: View {
    @StateObject private var viewModel = CommunityViewModel()
    
    var body: some View {
        NavigationView {
            List {
                // Add Friend Section
                Section(header: Text("Add Friend").font(.headline)) {
                    HStack {
                        Image(systemName: "person.badge.plus")
                        TextField("Enter friend's email or phone", text: $viewModel.newFriendIdentifier)
                            .textFieldStyle(RoundedBorderTextFieldStyle())
                            .autocapitalization(.none)
                            .disableAutocorrection(true)
                        Button(action: {
                            viewModel.sendFriendRequest()
                        }) {
                            Text("Add")
                                .foregroundColor(viewModel.newFriendIdentifier.isEmpty ? .gray : .blue)
                        }
                        .disabled(viewModel.newFriendIdentifier.isEmpty)
                    }
                }
                
                // Friend Requests Section
                Section(header: Text("Friend Requests").font(.headline)) {
                    if viewModel.isLoadingFriendRequests {
                        ProgressView()
                    } else if let error = viewModel.friendRequestLoadError {
                        Text(error)
                            .foregroundColor(.red)
                    } else if viewModel.friendRequests.isEmpty {
                        // Improved Empty State with an Icon
                        HStack {
                            Image(systemName: "person.crop.circle.badge.exclamationmark")
                                .foregroundColor(.gray)
                            Text("No pending friend requests")
                                .foregroundColor(.gray)
                        }
                    } else {
                        ForEach(viewModel.friendRequests, id: \.id) { request in
                            HStack {
                                // Placeholder Profile Image (could load from URL in real implementation)
                                Image(systemName: "person.crop.circle.fill")
                                    .resizable()
                                    .frame(width: 40, height: 40)
                                    .foregroundColor(.gray)
                                
                                VStack(alignment: .leading) {
                                    Text(request.fullName)
                                        .font(.headline)
                                    Text(request.email)
                                        .font(.subheadline)
                                        .foregroundColor(.secondary)
                                }
                                
                                Spacer()
                                
                                HStack {
                                    Button(action: {
                                        viewModel.acceptFriendRequest(request)
                                    }) {
                                        Image(systemName: "checkmark.circle.fill")
                                            .foregroundColor(.green)
                                            .imageScale(.large)
                                    }
                                    .disabled(viewModel.isProcessingRequest)
                                    
                                    Button(action: {
                                        viewModel.declineFriendRequest(request)
                                    }) {
                                        Image(systemName: "xmark.circle.fill")
                                            .foregroundColor(.red)
                                            .imageScale(.large)
                                    }
                                    .disabled(viewModel.isProcessingRequest)
                                }
                            }
                            .padding(.vertical, 4)
                        }
                    }
                }
                
                // Friends Section with Profile Image and Full Name
                Section(header: Text("Friends").font(.headline)) {
                    if viewModel.friends.isEmpty {
                        HStack {
                            Image(systemName: "person.3.fill")
                                .foregroundColor(.gray)
                            Text("No friends added yet")
                                .foregroundColor(.gray)
                        }
                    } else {
                        ForEach(viewModel.friends, id: \.id) { friend in
                            HStack {
                                Image(systemName: "person.crop.circle.fill")
                                    .resizable()
                                    .frame(width: 40, height: 40)
                                    .foregroundColor(.blue)
                                
                                VStack(alignment: .leading) {
                                    Text("\(friend.firstName) \(friend.lastName)")
                                        .font(.headline)
                                    Text(friend.email)
                                        .font(.subheadline)
                                        .foregroundColor(.secondary)
                                }
                                
                                Spacer()
                                
                                // Optional Online Status Indicator
                                Circle()
                                    .fill(Color.green)
                                    .frame(width: 10, height: 10)
                            }
                            .padding(.vertical, 4)
                        }
                    }
                }
                // Friends' Workouts Section
                Section(header: Text("Friends' Workouts").font(.headline)) {
                    if viewModel.workouts.isEmpty {
                        Text("No workouts available")
                            .foregroundColor(.gray)
                    } else {
                        ForEach(viewModel.workouts.sorted(by: { $0.date > $1.date })) { workout in
                            WorkoutRow(workout: workout)
                        }
                    }
                }
                            }
                            .listStyle(GroupedListStyle())
                        }
                        .onAppear {
                            DispatchQueue.main.async {
                                viewModel.loadData()
                                viewModel.loadFriendsWorkouts()
                            }
                        }
                        .alert(item: $viewModel.alertItem) { alertItem in
                            Alert(title: Text(alertItem.title),
                                  message: Text(alertItem.message),
                                  dismissButton: .default(Text("OK")))
                        }
                    }
                }



class CommunityViewModel: ObservableObject {
    @Published var newFriendIdentifier = ""
    @Published var friendRequests: [FriendRequest] = []
    @Published var friends: [User] = []
    @Published var workouts: [DetailedWorkout] = []
    @Published var alertItem: AlertItem?
    @Published var isLoadingFriendRequests = false
    @Published var isProcessingRequest = false
    @Published var friendRequestLoadError: String?
    
    private var db = Firestore.firestore()

    func sendFriendRequest() {
        guard let currentUser = Auth.auth().currentUser else {
            alertItem = AlertItem(title: "Error", message: "You must be logged in to send friend requests")
            return
        }
        
        findUser(by: newFriendIdentifier) { [weak self] friendID in
            guard let self = self, let friendID = friendID else {
                self?.alertItem = AlertItem(title: "Error", message: "User not found")
                return
            }
            
            if friendID == currentUser.uid {
                self.alertItem = AlertItem(title: "Error", message: "You can't add yourself as a friend")
                return
            }
            
            self.checkExistingFriendship(currentUserID: currentUser.uid, friendID: friendID) { exists in
                if exists {
                    self.alertItem = AlertItem(title: "Error", message: "Friendship already exists or is pending")
                } else {
                    self.db.collection("users").document(friendID).updateData([
                        "pendingFriendIds": FieldValue.arrayUnion([currentUser.uid])
                    ]) { error in
                        if let error = error {
                            self.alertItem = AlertItem(title: "Error", message: error.localizedDescription)
                        } else {
                            self.alertItem = AlertItem(title: "Success", message: "Friend request sent!")
                            self.newFriendIdentifier = ""
                        }
                    }
                }
            }
        }
    }

    // Find user by email or phone number
    func findUser(by identifier: String, completion: @escaping (String?) -> Void) {
        let field = identifier.contains("@") ? "email" : "phoneNumber"
        
        db.collection("users").whereField(field, isEqualTo: identifier).getDocuments { (querySnapshot, error) in
            if let error = error {
                print("Error finding user: \(error)")
                completion(nil)
            } else if let document = querySnapshot?.documents.first {
                completion(document.documentID)
            } else {
                completion(nil)
            }
        }
    }

    // Check if friendship already exists
    func checkExistingFriendship(currentUserID: String, friendID: String, completion: @escaping (Bool) -> Void) {
        let friendshipsRef = db.collection("friendships")

        // Check if the friendship already exists
        friendshipsRef
            .whereField("user1", isEqualTo: currentUserID)
            .whereField("user2", isEqualTo: friendID)
            .getDocuments { (querySnapshot, error) in
                if let error = error {
                    print("Error checking friendship: \(error)")
                    completion(false)
                } else if let documents = querySnapshot?.documents, !documents.isEmpty {
                    completion(true)
                } else {
                    // Check reverse relationship (user2 -> user1)
                    friendshipsRef
                        .whereField("user1", isEqualTo: friendID)
                        .whereField("user2", isEqualTo: currentUserID)
                        .getDocuments { (querySnapshot, error) in
                            if let error = error {
                                print("Error checking reverse friendship: \(error)")
                                completion(false)
                            } else if let documents = querySnapshot?.documents, !documents.isEmpty {
                                completion(true)
                            } else {
                                completion(false)
                            }
                        }
                }
            }
    }

    func loadFriendRequests() {
        guard let currentUserID = Auth.auth().currentUser?.uid else {
            friendRequestLoadError = "User not logged in"
            return
        }
        
        isLoadingFriendRequests = true
        friendRequestLoadError = nil
        
        db.collection("users").document(currentUserID).getDocument { [weak self] document, error in
            guard let self = self else { return }
            
            if let error = error {
                self.friendRequestLoadError = "Failed to load friend requests: \(error.localizedDescription)"
                self.isLoadingFriendRequests = false
                return
            }
            
            guard let data = document?.data(), let pendingFriendIds = data["pendingFriendIds"] as? [String] else {
                self.friendRequests = []
                self.isLoadingFriendRequests = false
                return
            }
            
            if pendingFriendIds.isEmpty {
                self.friendRequests = []
                self.isLoadingFriendRequests = false
                return
            }
            
            let group = DispatchGroup()
            var newFriendRequests: [FriendRequest] = []
            
            for friendID in pendingFriendIds {
                group.enter()
                self.db.collection("users").document(friendID).getDocument { (userDocument, error) in
                    defer { group.leave() }
                    
                    if let error = error {
                        print("Error fetching user details for ID \(friendID): \(error.localizedDescription)")
                        return
                    }
                    
                    guard let userData = userDocument?.data(),
                          let firstName = userData["firstName"] as? String,
                          let lastName = userData["lastName"] as? String,
                          let email = userData["email"] as? String else {
                        print("User data not found or incomplete for ID \(friendID)")
                        return
                    }
                    
                    let friendRequest = FriendRequest(id: friendID, senderID: friendID, firstName: firstName, lastName: lastName, email: email)
                    newFriendRequests.append(friendRequest)
                }
            }
            
            group.notify(queue: .main) {
                self.friendRequests = newFriendRequests
                self.isLoadingFriendRequests = false
            }
        }
    }
    
    func acceptFriendRequest(_ request: FriendRequest) {
        guard let currentUser = Auth.auth().currentUser else {
            alertItem = AlertItem(title: "Error", message: "You must be logged in to accept friend requests")
            return
        }

        guard !isProcessingRequest else { return }  // Prevent multiple triggers
        isProcessingRequest = true  // Start processing

        let batch = db.batch()

        let currentUserRef = db.collection("users").document(currentUser.uid)
        batch.updateData([
            "friendIds": FieldValue.arrayUnion([request.senderID]),
            "pendingFriendIds": FieldValue.arrayRemove([request.senderID])
        ], forDocument: currentUserRef)

        let friendUserRef = db.collection("users").document(request.senderID)
        batch.updateData([
            "friendIds": FieldValue.arrayUnion([currentUser.uid])
        ], forDocument: friendUserRef)

        // Create friendship in the friendships collection
        let friendshipID = db.collection("friendships").document().documentID
        let friendshipData: [String: Any] = [
            "user1": currentUser.uid,
            "user2": request.senderID,
            "createdAt": Timestamp(date: Date())
        ]
        let friendshipRef = db.collection("friendships").document(friendshipID)
        batch.setData(friendshipData, forDocument: friendshipRef)

        batch.commit { [weak self] error in
            DispatchQueue.main.async {
                if let error = error {
                    self?.alertItem = AlertItem(title: "Error", message: "Failed to accept friend request: \(error.localizedDescription)")
                } else {
                    self?.alertItem = AlertItem(title: "Success", message: "Friend request accepted successfully!")
                    self?.loadFriends()  // Load friends after acceptance to show updated friends list
                }
                self?.isProcessingRequest = false  // Stop processing
            }
        }
    }

    func declineFriendRequest(_ request: FriendRequest) {
        guard let currentUser = Auth.auth().currentUser else {
            alertItem = AlertItem(title: "Error", message: "You must be logged in to decline friend requests")
            return
        }
        
        guard !isProcessingRequest else { return }  // Prevent multiple triggers
        isProcessingRequest = true  // Start processing
        
        let currentUserRef = db.collection("users").document(currentUser.uid)
        currentUserRef.updateData([
            "pendingFriendIds": FieldValue.arrayRemove([request.senderID])
        ]) { [weak self] error in
            DispatchQueue.main.async {
                if let error = error {
                    self?.alertItem = AlertItem(title: "Error", message: "Failed to decline friend request: \(error.localizedDescription)")
                } else {
                    self?.alertItem = AlertItem(title: "Success", message: "Friend request declined successfully!")
                    self?.loadFriendRequests()
                }
                self?.isProcessingRequest = false  // Stop processing
            }
        }
    }
    
    private func isQualifyingWorkout(_ workout: DetailedWorkout) -> Bool {
        let distanceInMiles = workout.distance / 1609.34 // Convert meters to miles
        let paceInMinutesPerMile = (workout.pace ?? 0) / 60 // Convert seconds per km to minutes per mile

        switch workout.type {
        case .running:
            return distanceInMiles >= 2 && paceInMinutesPerMile <= 12 // 2 miles and pace better than 12 min/mile
        case .cycling:
            return distanceInMiles >= 6 && paceInMinutesPerMile <= 4 // 6 miles and pace better than 4 min/mile
        default:
            return false
        }
    }
    
    func loadData() {
        loadFriends()
        loadFriendRequests()
    }
    
    private func loadFriends() {
        guard let currentUserID = Auth.auth().currentUser?.uid else { return }
        
        db.collection("users").document(currentUserID).getDocument { [weak self] document, error in
            guard let data = document?.data(), let friendIds = data["friendIds"] as? [String], !friendIds.isEmpty else {
                self?.friends = []
                return
            }
            
            // Fetch user details for each friendId
            self?.fetchUserDetails(for: friendIds)
        }
    }

    private func fetchUserDetails(for userIDs: [String]) {
        let group = DispatchGroup()
        var fetchedFriends: [User] = []
        
        for userID in userIDs {
            group.enter()
            db.collection("users").document(userID).getDocument { (document, error) in
                if let document = document, document.exists,
                   let firstName = document.data()?["firstName"] as? String,
                   let lastName = document.data()?["lastName"] as? String,
                   let email = document.data()?["email"] as? String {
                    fetchedFriends.append(User(id: userID, firstName: firstName, lastName: lastName, email: email))
                }
                group.leave()
            }
        }
        
        group.notify(queue: .main) { [weak self] in
            self?.friends = fetchedFriends
        }
    }
    
    func loadFriendsWorkouts() {
        guard let currentUserID = Auth.auth().currentUser?.uid else {
            print("Error: User not logged in")
            return
        }
        
        db.collection("users").document(currentUserID).getDocument { [weak self] document, error in
            guard let self = self, let data = document?.data(), let friendIds = data["friendIds"] as? [String], !friendIds.isEmpty else {
                print("Error: No friend IDs found")
                return
            }
            
            print("Friend IDs: \(friendIds)")
            
            let group = DispatchGroup()
            var fetchedWorkouts: [DetailedWorkout] = []
            
            for friendID in friendIds {
                group.enter()
                
                // First, fetch the friend's user data
                self.db.collection("users").document(friendID).getDocument { (userDoc, userError) in
                    if let userError = userError {
                        print("Error fetching user data for \(friendID): \(userError.localizedDescription)")
                        group.leave()
                        return
                    }
                    
                    guard let userData = userDoc?.data(),
                          let firstName = userData["firstName"] as? String,
                          let lastName = userData["lastName"] as? String else {
                        print("Missing user data for \(friendID)")
                        group.leave()
                        return
                    }
                    
                    let profilePictureUrl = userData["profilePictureUrl"] as? String
                    
                    // Now fetch the workouts for this friend
                    self.db.collection("workouts")
                        .whereField("userId", isEqualTo: friendID)
                        .whereField("date", isGreaterThanOrEqualTo: Timestamp(date: Date().startOfMonth()))
                        .whereField("date", isLessThanOrEqualTo: Timestamp(date: Date().endOfMonth()))
                        .getDocuments { (snapshot, error) in
                            if let error = error {
                                print("Error fetching workouts for user \(friendID): \(error.localizedDescription)")
                            } else {
                                print("Found \(snapshot?.documents.count ?? 0) workouts for user \(friendID)")
                                
                                let friendWorkouts = snapshot?.documents.compactMap { doc -> DetailedWorkout? in
                                    let data = doc.data()
                                    print("Workout data: \(data)")
                                    
                                    guard let id = UUID(uuidString: data["id"] as? String ?? ""),
                                          let timestamp = data["date"] as? Timestamp,
                                          let distance = data["distance"] as? Double,
                                          let duration = data["duration"] as? TimeInterval,
                                          let calories = data["calories"] as? Double,
                                          let typeRawValue = data["type"] as? UInt
                                    else {
                                        print("Missing required fields in workout document")
                                        return nil
                                    }
                                    
                                    let type = HKWorkoutActivityType(rawValue: typeRawValue) ?? .other
                                    let averageHeartRate = data["averageHeartRate"] as? Double
                                    let maxHeartRate = data["maxHeartRate"] as? Double
                                    let stepsCount = data["stepsCount"] as? Double
                                    let pace = data["pace"] as? TimeInterval
                                    let routeImageUrl = data["routeImageUrl"] as? String
                                    let intensityRawValue = data["intensity"] as? String ?? ""
                                    let intensity = WorkoutIntensity(rawValue: intensityRawValue) ?? .moderate
                                    let averageCadence = data["averageCadence"] as? Double
                                    let weather = data["weather"] as? String
                                    let sourceName = data["sourceName"] as? String
                                    
                                    let workout = DetailedWorkout(
                                                                        id: id,
                                                                        type: type,
                                                                        distance: distance,
                                                                        duration: duration,
                                                                        calories: calories,
                                                                        date: timestamp.dateValue(),
                                                                        averageHeartRate: averageHeartRate,
                                                                        maxHeartRate: maxHeartRate,
                                                                        stepsCount: stepsCount,
                                                                        pace: pace,
                                                                        routeImageUrl: routeImageUrl,
                                                                        intensity: intensity,
                                                                        averageCadence: averageCadence,
                                                                        weather: weather,
                                                                        sourceName: sourceName,
                                                                        userFirstName: firstName,
                                                                        userLastName: lastName,
                                                                        userProfilePictureUrl: profilePictureUrl
                                                                    )
                                                                    
                                                                    // Only return the workout if it's qualifying
                                                                    return self.isQualifyingWorkout(workout) ? workout : nil
                                                                }.compactMap { $0 } // This removes any nil values
                                                                
                                print("Parsed \((friendWorkouts ?? []).count) qualifying workouts for user \(friendID)")
                                fetchedWorkouts.append(contentsOf: friendWorkouts ?? [])
                                                            }
                                                            group.leave()
                                                        }
                                                }
                                            }
                                            
                                            group.notify(queue: .main) {
                                                print("Fetched \(fetchedWorkouts.count) total qualifying workouts from friends.")
                                                self.workouts = fetchedWorkouts.sorted(by: { $0.date > $1.date })
                                            }
                                        }
                                    }
    
}

// Models

struct FriendRequest: Identifiable {
    let id: String
    let senderID: String
    let firstName: String
    let lastName: String
    let email: String

    var fullName: String {
        "\(firstName) \(lastName)"
    }
}

struct User: Identifiable {
    let id: String
    let firstName: String
    let lastName: String
    let email: String
}

struct Workout {
    let id: String
    let userID: String
    let distance: Double
    let duration: Double  // Duration in minutes or seconds
    let type: String
    let timestamp: Date
    let calories: Double
    let averageHeartRate: Int
    let maxHeartRate: Int
    let stepsCount: Int
    let intensity: String
    let routeImageUrl: String?

    // Pace can be derived from distance and duration
    var pace: Double {
        return distance > 0 ? duration / distance : 0.0
    }

    init(id: String, userID: String, distance: Double, duration: Double, type: String, timestamp: Date, calories: Double, averageHeartRate: Int, maxHeartRate: Int, stepsCount: Int, intensity: String, routeImageUrl: String?) {
        self.id = id
        self.userID = userID
        self.distance = distance
        self.duration = duration
        self.type = type
        self.timestamp = timestamp
        self.calories = calories
        self.averageHeartRate = averageHeartRate
        self.maxHeartRate = maxHeartRate
        self.stepsCount = stepsCount
        self.intensity = intensity
        self.routeImageUrl = routeImageUrl
    }

    // Initialize from Firestore data
    init(data: [String: Any]) {
        self.id = data["id"] as? String ?? UUID().uuidString
        self.userID = data["userId"] as? String ?? ""
        self.distance = data["distance"] as? Double ?? 0.0
        self.duration = data["duration"] as? Double ?? 0.0
        self.type = data["type"] as? String ?? ""
        self.timestamp = (data["timestamp"] as? Timestamp)?.dateValue() ?? Date()
        self.calories = data["calories"] as? Double ?? 0.0
        self.averageHeartRate = data["averageHeartRate"] as? Int ?? 0
        self.maxHeartRate = data["maxHeartRate"] as? Int ?? 0
        self.stepsCount = data["stepsCount"] as? Int ?? 0
        self.intensity = data["intensity"] as? String ?? ""
        self.routeImageUrl = data["routeImageUrl"] as? String
    }
}



struct AlertItem: Identifiable {
    let id = UUID()
    let title: String
    let message: String
}

extension DateFormatter {
    static var shortDateAndTime: DateFormatter {
        let formatter = DateFormatter()
        formatter.dateStyle = .short
        formatter.timeStyle = .short
        return formatter
    }
}

extension Date {
    // Returns the start of the month for a given date
    func startOfMonth() -> Date {
        let calendar = Calendar.current
        let components = calendar.dateComponents([.year, .month], from: self)
        return calendar.date(from: components)!
    }

    // Returns the end of the month for a given date
    func endOfMonth() -> Date {
        let calendar = Calendar.current
        if let startOfMonth = calendar.date(from: calendar.dateComponents([.year, .month], from: self)),
           let endOfMonth = calendar.date(byAdding: DateComponents(month: 1, day: -1), to: startOfMonth) {
            return endOfMonth
        }
        return self
    }
}

#Preview {
    CommunityView()
}


