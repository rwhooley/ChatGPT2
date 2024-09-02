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
                VStack {
                    Text(currentMonthYear)
                        .font(.title)
                        .fontWeight(/*@START_MENU_TOKEN@*/.bold/*@END_MENU_TOKEN@*/)
                    Spacer()
                    Text(activeInvestment != nil ? "Active Investment" : "No Active Investment")
                        .foregroundColor(activeInvestment != nil ? .green : .gray)
                        .font(.headline)
                }
                .padding(.bottom, 20)
                
                VStack(alignment: .leading, spacing: 8) {
                    // Earned and Possible Amounts
                    Text("Earnings 💵")
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
                    
                    Text("Progress 🏃‍♀️‍➡️")
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
    #Preview {
        HomeView()
            .environmentObject(HealthKitManager())
    }
