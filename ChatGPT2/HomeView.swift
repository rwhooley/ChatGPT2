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
    
    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 20) {
                VStack(alignment: .leading, spacing: 10) {
                    HStack {
                        Text(currentMonthYear)
                            .font(.title)
                            .fontWeight(.bold)
                        
                        Button(action: {
                            showingExplanation = true
                        }) {
                            Image(systemName: "questionmark.circle")
                                .font(.title3)
                                .foregroundColor(.gray)
                        }
                        .sheet(isPresented: $showingExplanation) {
                            ExplanationView()
                        }
                    }
                    
                    Text(activeInvestment != nil ? "Active Investment" : "No Active Investment. Make a deposit to invest.")
                        .foregroundColor(activeInvestment != nil ? .green : .gray)
                        .font(.headline)
                }
                .padding(.bottom, 20)
                
                VStack(alignment: .leading, spacing: 8) {
                    Text("Earnings")
                        .font(.title)
                        .fontWeight(.bold)
                    
                    HStack(spacing: 20) {
                        VStack {
                            Text("Earned")
                                .font(.subheadline)
                                .foregroundColor(.gray)
                                .padding(.top, 10)
                                .frame(maxWidth: .infinity, alignment: .center)
                            Spacer()
                            Text("$\(Int(totalEarnedAmount))")
                                .font(.title2)
                                .fontWeight(.bold)
                                .frame(maxWidth: .infinity, alignment: .center)
                            Spacer()
                        }
                        .frame(maxWidth: .infinity, minHeight: 80)
                        .padding()
                        .background(RoundedRectangle(cornerRadius: 10).fill(Color.gray.opacity(0.2)))
                        
                        VStack {
                            Text("Potential")
                                .font(.subheadline)
                                .foregroundColor(.gray)
                                .padding(.top, 10)
                                .frame(maxWidth: .infinity, alignment: .center)
                            Spacer()
                            Text("$\(Int(possibleAmount))")
                                .font(.title2)
                                .fontWeight(.bold)
                                .frame(maxWidth: .infinity, alignment: .center)
                            Spacer()
                        }
                        .frame(maxWidth: .infinity, minHeight: 80)
                        .padding()
                        .background(RoundedRectangle(cornerRadius: 10).fill(Color.gray.opacity(0.2)))
                    }
                    
                    Spacer()
                    
                    Text("Progress")
                        .font(.title)
                        .fontWeight(.bold)
                }
                
                LazyVGrid(columns: columns, spacing: 10) {
                                    ForEach(0..<12, id: \.self) { index in
                                        ZStack {
                                            RoundedRectangle(cornerRadius: 5)
                                                .fill(index < completedSquares ? Color.green : (index >= 10 ? Color.orange.opacity(0.3) : Color.gray.opacity(0.3)))
                                                .frame(height: (UIScreen.main.bounds.width - 50) / 4)
                                            
                                            Text(activeInvestment != nil ?
                                                 (index < 10 ? "$\(Int(activeInvestment!.amount / 10))" : "$25") :
                                                    "$0")
                                            .font(.body)
                                            .fontWeight(.bold)
                                            .foregroundColor(index < completedSquares ? .white : .black)
                                        }
                                        .onTapGesture {
                                            if index < completedWorkouts.count {
                                                selectedWorkout = completedWorkouts[index]
                                                showingWorkoutDetail = true
                                            }
                                        }
                                    }
                                }
                            }
                            .padding()
                        }
                        .overlay(
                            Group {
                                if showingWorkoutDetail, let workout = selectedWorkout {
                                    Color.black.opacity(0.3)
                                        .edgesIgnoringSafeArea(.all)
                                        .onTapGesture {
                                            showingWorkoutDetail = false
                                        }
                                    
                                    WorkoutDetailView(workout: workout) {
                                        showingWorkoutDetail = false
                                    }
                                    .transition(.scale)
                                    .animation(.easeInOut, value: showingWorkoutDetail)
                                }
                            }
                        )
                        .navigationTitle("Home")
                        .onAppear {
                            fetchCurrentMonthWorkouts()
                            fetchCurrentMonthInvestment()
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
