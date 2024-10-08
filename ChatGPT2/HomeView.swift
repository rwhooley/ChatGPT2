//
//  HomeView.swift
//  ChatGPT2
//
//  Created by Ryan Whooley on 8/25/24.
//

import SwiftUI
import HealthKit
import Firebase
import FirebaseFirestore
import FirebaseAuth
import CoreLocation

struct HomeView: View {
    @EnvironmentObject private var healthKitManager: HealthKitManager
    @StateObject private var bankViewModel = BankViewModel()
    @State private var activeInvestment: Investment?
    @State private var showingExplanation = false
    @State private var completedWorkouts: [DetailedWorkout] = []
    @State private var selectedWorkout: DetailedWorkout?
    @State private var showingWorkoutDetail = false
    @State private var detailPosition: CGPoint = .zero
    
    @State private var isPersonalExpanded = true
    @State private var isGroupExpanded = false
    @State private var isFriendsExpanded = false
    
    @State private var activeContests: [String] = []  // Replace with actual data
    @State private var activeCollaborations: [String] = []  // Replace with actual data
    
    @State private var selectedSection: HomeSection = .personal
    
    @State private var userFirstName: String = ""
    
    @State private var greetingDismissed = false
    
    @State private var personalPlans: [PersonalPlan] = []
    
    @State private var offersDismissed = false
    @State private var offers: [Offer] = [
        Offer(name: "Bandit", imageName: "Bandit"),
        Offer(name: "SoulCycle", imageName: "SoulCycle"),
        Offer(name: "BK Running Co.", imageName: "BKRunning"),
        Offer(name: "Peleton", imageName: "Peloton"),
    ]

    
    
    private var greetingModule: some View {
        let text: String
        let backgroundColor: Color = Color.gray.opacity(0.2) // Same gray color as the segmented control
        let cornerRadius: CGFloat = 8 // Adjust to match the corner radius of the picker

        switch selectedSection {
        case .personal:
            text = """
            It’s you versus yourself…and your wallet! Invest in a monthly plan and crush all your workouts to earn a bonus. Consistency is key. If you miss workouts, you might leave money on the table!
            """
        case .contests:
            text = """
            How about a wager among friends to bring out your competitive side? Create a workout contest, invite friends to join and invest, then compete to see who can earn the most money from the pot.
            """
        case .collaborations:
            text = """
            Common goals are powerful forces. Create a team, pledge money towards a workout goal, then hold eachother accountable to complete it. If one teammate misses workouts, the whole team loses.
            """
        }

        return Group {
            if !greetingDismissed {
                HStack {
                    Text(text)
                        .font(.caption)
                        .padding() // Add padding to the text inside
                        .frame(maxWidth: .infinity, alignment: .leading)
                    
                    // Dismiss button
                    Button(action: {
                        greetingDismissed = true
                    }) {
                        Image(systemName: "xmark.circle.fill")
                            .foregroundColor(.white)
                            .padding(.trailing, 10)
                    }
                }
                .background(backgroundColor) // Use gray background like the picker
                .cornerRadius(cornerRadius) // Match the corner radius of the segmented picker
                .padding(.horizontal, 0) // Align the greeting module with the picker width
                .padding(.top, 10) // Padding between the picker and greeting
            }
        }
    }


    
    private var completedSquares: Int {
        min(completedWorkouts.count, 12)
    }
    
    var totalEarnedAmount: Double {
        guard let investment = activeInvestment else { return 0 }
        let baseAmount = Double(min(completedSquares, 10)) * (investment.amount / 10.0)
        let bonusAmount = Double(max(0, min(completedSquares - 10, 2))) * 25.0
        return baseAmount + bonusAmount
    }
    
    var possibleAmount: Double {
        guard let investment = activeInvestment else { return 0 }
        return (investment.amount / 10.0 * 10) + (25.0 * 2)
    }
    
    let columns = Array(repeating: GridItem(.flexible(), spacing: 10), count: 4)
    
    var currentMonthYear: String {
        let formatter = DateFormatter()
        formatter.dateFormat = "MMMM yyyy"
        return formatter.string(from: Date())
    }
    
    enum HomeSection: String, CaseIterable {
        case personal = "Personal"
        case contests = "Contests"
        case collaborations = "Teams"
//        case friends = "Friends"
    }
    
    struct Offer {
        let name: String
        let imageName: String
    }
    
    var body: some View {
            VStack(spacing: 0) {
//                if !offersDismissed {
//                    // Offers title and dismiss button
//                    HStack {
//                        
//                        Button(action: {
//                            offersDismissed = true
//                        }) {
//                            Image(systemName: "xmark.circle.fill")
//                                .foregroundColor(.gray)
//                                .padding(.leading, 20)  // Move button to the left
//                        }
//
//                        Spacer()
//
//                        
//                    }
//                    .padding(.top, 10)
//
//                    // Offers module
//                    ScrollView(.horizontal, showsIndicators: false) {
//                        HStack(spacing: 1) {  // Adjust spacing
//                            ForEach(offers, id: \.name) { offer in
//                                OfferView(offer: offer.name, imageName: offer.imageName)
//                            }
//                        }
//                        .padding(.horizontal)
//                    }
////                    .padding(.top, 10)
//                    .frame(height: 100)  // Adjust height as needed for the whole offer section
//                }

//                Text("Workouts")
//                    .font(.headline)
//                    .foregroundColor(.primary)
//                    .frame(alignment: .leading)
                
            // Segmented Picker (3-way toggle)
                       Picker("Select Section", selection: $selectedSection) {
                           ForEach(HomeSection.allCases, id: \.self) { section in
                               Text(section.rawValue).tag(section)
                           }
                       }
                       .pickerStyle(SegmentedPickerStyle())
                       .padding(.horizontal)
                       .padding(.top, 15)
            
            greetingModule
                .padding(.horizontal)
                .padding(.bottom, 8)
                       
                       // Content based on selected section
                       ScrollView {
                           VStack(alignment: .leading, spacing: 20) {
                               switch selectedSection {
                               case .personal:
                                   HomePersonalView(
                                       activeInvestment: $activeInvestment,
                                       completedWorkouts: $completedWorkouts,
                                       selectedWorkout: $selectedWorkout,
                                       showingWorkoutDetail: $showingWorkoutDetail,
                                       personalPlans: $personalPlans
                                   )
                               case .contests:
                                   HomeContestsView()
                               case .collaborations:
                                   HomeTeamsView()
                               }
                           }
                           .padding()
                       }
                   }
                   .navigationTitle("Home")
                   .onAppear {
                       fetchCurrentMonthWorkouts()
                       fetchCurrentMonthInvestment()
                       fetchUserFirstName()
                       fetchPersonalPlans()
                   }
               }
    
    func fetchPersonalPlans() {
        guard let userId = Auth.auth().currentUser?.uid else { return }
        
        Firestore.firestore().collection("Investments")
            .whereField("userId", isEqualTo: userId)
            .getDocuments { snapshot, error in
                if let error = error {
                    print("Error fetching personal plans: \(error.localizedDescription)")
                    return
                }
                
                self.personalPlans = snapshot?.documents.compactMap { document in
                    let data = document.data()
                    return PersonalPlan(
                        id: document.documentID,
                        amount: data["amount"] as? Double ?? 0,
                        bonusRate: data["bonusRate"] as? Double ?? 0, // New field
                        bonusSquares: data["bonusSquares"] as? Int ?? 0, // New field
                        workoutCount: data["workoutCount"] as? Int ?? 0, // New field
                        month: data["month"] as? String ?? "",
                        timestamp: (data["timestamp"] as? Timestamp)?.dateValue() ?? Date(),
                        userId: data["userId"] as? String ?? ""
                    )
                } ?? []
            }
    }

   
    
    private func fetchUserFirstName() {
        guard let userId = Auth.auth().currentUser?.uid else {
            print("Debug: No current user ID available")
            return
        }
        
        let db = Firestore.firestore()
        db.collection("users").document(userId).getDocument { (document, error) in
            if let error = error {
                print("Debug: Error fetching user document: \(error.localizedDescription)")
                return
            }
            
            guard let document = document, document.exists else {
                print("Debug: User document does not exist")
                return
            }
            
            if let firstName = document.data()?["firstName"] as? String {
                print("Debug: Fetched firstName: '\(firstName)'")
                DispatchQueue.main.async {
                    self.userFirstName = firstName
                }
            } else {
                print("Debug: 'firstName' field not found or not a string in user document")
                DispatchQueue.main.async {
                    self.userFirstName = "there"
                }
            }
        }
    }
    
    private func fetchCurrentMonthInvestment() {
        bankViewModel.fetchCurrentMonthInvestment { investment in
            self.activeInvestment = investment
        }
    }
    
    private func fetchCurrentMonthWorkouts() {
        guard let userId = healthKitManager.getCurrentUserId() else {
            print("Error: Unable to get current user ID.")
            return
        }
        
        let calendar = Calendar.current
        let now = Date()
        let startOfMonth = calendar.date(from: calendar.dateComponents([.year, .month], from: now))!
        let endOfMonth = calendar.date(byAdding: DateComponents(month: 1, day: -1), to: startOfMonth)!
        
        healthKitManager.db.collection("workouts")
                    .whereField("userId", isEqualTo: userId)  // Fetching from the top-level collection
                    .whereField("date", isGreaterThanOrEqualTo: Timestamp(date: startOfMonth))
                    .whereField("date", isLessThanOrEqualTo: Timestamp(date: endOfMonth))
                    .getDocuments { (snapshot, error) in
                        if let error = error {
                            print("Error fetching workouts: \(error.localizedDescription)")
                            return
                        }
                
                guard let documents = snapshot?.documents else {
                    print("No documents found")
                    return
                }
                
                self.completedWorkouts = documents.compactMap { document -> DetailedWorkout? in
                        let data = document.data()
                        let distance = data["distance"] as? Double ?? 0
                        let duration = data["duration"] as? TimeInterval ?? 0
                        let pace = (duration > 0 && distance > 0) ? duration / (distance / 1000) : 0
                        
                    let workout = DetailedWorkout(
                        id: UUID(uuidString: data["id"] as? String ?? "") ?? UUID(),
                        type: self.getWorkoutType(from: data["type"] as? UInt ?? 0),
                        distance: distance,
                        duration: duration,
                        calories: data["calories"] as? Double ?? 0,
                        date: (data["date"] as? Timestamp)?.dateValue() ?? Date(),
                        averageHeartRate: data["averageHeartRate"] as? Double,
                        maxHeartRate: data["maxHeartRate"] as? Double,
                        stepsCount: data["stepsCount"] as? Double,
                        pace: pace,
                        routeImageUrl: data["routeImageUrl"] as? String,
                        intensity: WorkoutIntensity(rawValue: data["intensity"] as? String ?? "moderate") ?? .moderate,
                        averageCadence: data["averageCadence"] as? Double,
                        weather: data["weather"] as? String,
                        sourceName: data["sourceName"] as? String,
                        userFirstName: data["userFirstName"] as? String ?? "",  // Add this line
                        userLastName: data["userLastName"] as? String ?? "",   // Add this line
                        userProfilePictureUrl: data["userProfilePictureUrl"] as? String  // Add this line
                    )
                        return self.isQualifyingWorkout(workout) ? workout : nil
                    }
                    print("Fetched \(self.completedWorkouts.count) qualifying workouts")
                }
    }
    
    private func getWorkoutType(from value: UInt) -> HKWorkoutActivityType {
        return HKWorkoutActivityType(rawValue: value) ?? .other
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
}

struct ExplanationView: View {
    var body: some View {
        VStack(alignment: .leading, spacing: 15) {
            Text("Welcome to Antelope Fitness Club")
                .font(.title)
                .fontWeight(.bold)
                .padding(.bottom, 20)
            
            Text("Sticking to workout plans is hard. We're here to help!")
                .font(.headline)
                .fontWeight(.bold)
                .padding(.bottom, 10)
            
            Text("Here's how it works:")
                .font(.subheadline)
                .padding(.bottom, 10)
            
            VStack(alignment: .leading, spacing: 8) {
                Text("1. Make a deposit.")
                    .fontWeight(.bold)
                Text("Connect your banking information so that you can make withdrawals when the time comes. Then make a deposit via credit card.")
                    .font(.caption)
                
                Text("2. Invest in a monthly workout plan.")
                    .fontWeight(.bold)
                Text("Each workout plan requires 12 workouts per month. A workout is a run of >2 miles with an average pace better than 12 min/mile, or a cycle of >6 miles with an average pace better than 4 min/mile.")
                    .font(.caption)
                
                Text("3. Connect to Apple Health in your Antelope app.")
                    .fontWeight(.bold)
                Text("For now, you also need to download Strava, Nike Run Club, or Map My Run and enable them to push workout data to Apple Health. We are working on bringing workout tracking in-house but need some more time.")
                    .font(.caption)
                
                Text("4. Complete your workouts.")
                    .fontWeight(.bold)
                Text("Make sure to record them on Strava or one of the other apps. Antelope will listen to Apple Health and automatically pick them up.")
                    .font(.caption)
                
                Text("5. Earn money!")
                    .fontWeight(.bold)
                Text("Complete 10 workouts in a month to earn your investment back. Complete 11 or 12 workouts to earn a bonus!")
                    .font(.caption)
            }
            .padding(.leading, 10)
        }
        .padding()
    }
}

struct BoxPreference: Equatable {
    let index: Int
    let frame: CGRect
}

struct BoxPreferenceKey: PreferenceKey {
    static var defaultValue: [BoxPreference] = []
    
    static func reduce(value: inout [BoxPreference], nextValue: () -> [BoxPreference]) {
        value.append(contentsOf: nextValue())
    }
}

struct WorkoutDetailView: View {
    let workout: DetailedWorkout
    var onDismiss: () -> Void
    
    var body: some View {
        VStack(alignment: .leading, spacing: 10) {
            HStack {
                Text(workout.date, style: .date)
                    .font(.headline)
                Spacer()
                Button(action: onDismiss) {
                    Image(systemName: "xmark.circle.fill")
                        .foregroundColor(.gray)
                }
            }
            Text(workout.type == .running ? "Running" : "Cycling")
                .font(.subheadline)
            Text(String(format: "Distance: %.2f miles", workout.distance / 1609.34))
            Text("Duration: \(formatDuration(workout.duration))")
        }
        .padding()
        .background(Color.white)
        .cornerRadius(10)
        .shadow(radius: 5)
        .frame(width: 250, height: 150)
    }
    
    private func formatDuration(_ duration: TimeInterval) -> String {
        let formatter = DateComponentsFormatter()
        formatter.allowedUnits = [.hour, .minute, .second]
        formatter.unitsStyle = .abbreviated
        return formatter.string(from: duration) ?? ""
    }
}

#Preview {
    HomeView()
        .environmentObject(HealthKitManager())
}
