//
//  HomeView.swift
//  ChatGPT2
//
//  Created by Ryan Whooley on 8/25/24.
//

import SwiftUI
import HealthKit

struct HomeView: View {
    @EnvironmentObject private var healthKitManager: HealthKitManager
    @StateObject private var bankViewModel = BankViewModel()
    @State private var activeInvestment: Investment?
    @State private var showingExplanation = false // State to control the display of the explanation view
    
    // Filter workouts that qualify based on current month, year, and workout criteria
    var completedWorkouts: [DetailedWorkout] {
        healthKitManager.workouts.filter { workout in
            let workoutDate = workout.date
            let currentMonth = Calendar.current.component(.month, from: Date())
            let currentYear = Calendar.current.component(.year, from: Date())
            let workoutMonth = Calendar.current.component(.month, from: workoutDate)
            let workoutYear = Calendar.current.component(.year, from: workoutDate)
            return workoutMonth == currentMonth && workoutYear == currentYear && isQualifyingWorkout(workout)
        }
    }
    
    var completedSquares: Int {
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

                          

                            // "?" Button to show the explanation view
                            Button(action: {
                                showingExplanation = true
                            }) {
                                Image(systemName: "questionmark.circle")
                                    .font(.title3)
                                    .foregroundColor(.gray)
                            }
                            .sheet(isPresented: $showingExplanation) {
                                ExplanationView() // Presents the explanation view
                            }
                        }

                        Text(activeInvestment != nil ? "Active Investment" : "No Active Investment.                                     Make a deposit to invest.")
                            .foregroundColor(activeInvestment != nil ? .green : .gray)
                            .font(.headline)
                    }
                    .padding(.bottom, 20)

                    VStack(alignment: .leading, spacing: 8) {
                        // Earned and Possible Amounts
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

                    // Grid of workout squares
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
                        }
                    }
                }
                .padding()
            }
            .navigationTitle("Home")
            .onAppear {
                fetchWorkouts()
                fetchCurrentMonthInvestment()
            }
        }

        private func fetchWorkouts() {
            healthKitManager.fetchAllDetailedWorkouts { _, _ in
                // You can add any additional logic here if needed
            }
        }

        private func fetchCurrentMonthInvestment() {
            bankViewModel.fetchCurrentMonthInvestment { investment in
                self.activeInvestment = investment
            }
        }

        private func isQualifyingWorkout(_ workout: DetailedWorkout) -> Bool {
            switch workout.type {
            case .running:
                return workout.distance >= 3218.69 // 2 miles
            case .cycling:
                return workout.distance >= 9656.06 // 6 miles
            default:
                return false
            }
        }
    }

    // New view to display explanation text
struct ExplanationView: View {
    var body: some View {
        VStack(alignment: .leading, spacing: 15) {
            Text("Welcome to Antelope Fitness Club")
                .font(.title)
                .fontWeight(.bold)
                .padding(.bottom, 20)
            
            Text("Sticking to workout plans is hard. We’re here to help!")
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

    #Preview {
        HomeView()
            .environmentObject(HealthKitManager())
    }
