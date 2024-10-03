//
//  HomePersonalView.swift
//  ChatGPT2
//
//  Created by Ryan Whooley on 9/17/24.
//

import SwiftUI
import Firebase
import FirebaseAuth
import FirebaseFirestore

struct HomePersonalView: View {
    @Binding var activeInvestment: Investment?
    @Binding var completedWorkouts: [DetailedWorkout]
    @Binding var selectedWorkout: DetailedWorkout?
    @Binding var showingWorkoutDetail: Bool
    @Binding var personalPlans: [PersonalPlan]
    @State private var showingCreatePersonalInvestment = false
    @State private var currentMonthInvestment: Investment?
    @StateObject var bankViewModel = BankViewModel()
    @State private var currentMonthInvestments: [Investment] = []
    @State private var qualifyingWorkoutsCount: Int = 0
    @State private var isLoading = true


//    private var shouldUpdateQualifyingWorkouts: Bool {
//            // This computed property will be called whenever the view updates
//            updateQualifyingWorkoutsCount()
//            return updateTrigger
//        }
    
    
    
    private var completedSquares: Int {
           min(qualifyingWorkoutsCount, currentMonthInvestment?.workoutCount ?? 0)
       }
    
    func totalEarnedAmount(for investment: Investment) -> Double {
        let completedSquares = min(completedWorkouts.count, investment.workoutCount)
        let baseAmount = Double(min(completedSquares, investment.workoutCount - investment.bonusSquares)) * (investment.amount / Double(investment.workoutCount - investment.bonusSquares))
        let bonusAmount = Double(max(0, completedSquares - (investment.workoutCount - investment.bonusSquares))) * (investment.amount * (investment.bonusRate / 100.0) / Double(investment.bonusSquares))
        return baseAmount + bonusAmount
    }

    func possibleAmount(for investment: Investment) -> Double {
        let baseAmount = investment.amount
        let bonusAmount = investment.amount * (investment.bonusRate / 100.0)
        return baseAmount + bonusAmount
    }

    
    let columns = Array(repeating: GridItem(.flexible(), spacing: 10), count: 4)
    
    
    
    var currentMonthYear: String {
        let formatter = DateFormatter()
        formatter.dateFormat = "MMMM yyyy"
        return formatter.string(from: Date())
    }
    
    
    
    var body: some View {
            VStack(alignment: .leading, spacing: 20) {
                Text("Active Personal Investments")
                    .font(.title2)
                    .fontWeight(.bold)
                
                if isLoading {
                    ProgressView("Loading investments...")
                } else if currentMonthInvestments.isEmpty {
                    Text("No Active Investment. Make a deposit to invest.")
                        .foregroundColor(.gray)
                        .font(.headline)
                        .padding()
                        .frame(maxWidth: .infinity, alignment: .center)
                        .background(Color.gray.opacity(0.1))
                        .cornerRadius(12)
                } else {
                    ForEach(currentMonthInvestments, id: \.id) { investment in
                        VStack(alignment: .leading, spacing: 0) {
                            CollapsiblePersonalPlanView(personalPlan: PersonalPlan(
                                id: investment.id,
                                amount: investment.amount,
                                month: investment.month ?? "Unknown",
                                timestamp: investment.timestamp ?? Date(),
                                userId: investment.userId ?? ""
                            ))
                            .padding(.horizontal)
                            .padding(.vertical, 12)
                            .background(Color.green.opacity(0.2))
                            
                            earningsContent(for: investment)
                                .padding(.horizontal)
                                .padding(.vertical, 16)
                                .background(Color(UIColor.secondarySystemBackground))
                            
                            progressContent(for: investment)
                                .padding(.horizontal)
                                .padding(.vertical, 16)
                                .background(Color(UIColor.secondarySystemBackground))
                        }
                        .background(Color(UIColor.secondarySystemBackground))
                        .cornerRadius(12)
                    }
                }
                
                Button(action: {
                    showingCreatePersonalInvestment = true
                }) {
                    HStack {
                        Image(systemName: "plus.circle.fill")
                            .font(.system(size: 18))
                            .foregroundColor(.white)
                        
                        Text("Create New Investment")
                            .font(.headline)
                            .foregroundColor(.white)
                    }
                    .frame(maxWidth: .infinity)
                    .padding()
                    .background(Color.gray.opacity(0.2))
                    .cornerRadius(10)
                }
            }
            .frame(maxHeight: .infinity)
                    .onAppear {
                        isLoading = true
                        fetchInvestmentsForCurrentMonth()
                    }
                    .onChange(of: completedWorkouts) { _ in
                        updateQualifyingWorkoutsCount()
                    }
                    .sheet(isPresented: $showingCreatePersonalInvestment) {
                        CreatePersonalInvestmentView()
            }
        }
    
    func updateQualifyingWorkoutsCount() {
            let calendar = Calendar.current
            let currentDate = Date()
            let currentMonth = calendar.component(.month, from: currentDate)
            let currentYear = calendar.component(.year, from: currentDate)

            qualifyingWorkoutsCount = completedWorkouts.filter { workout in
                let workoutMonth = calendar.component(.month, from: workout.date)
                let workoutYear = calendar.component(.year, from: workout.date)
                
                guard workoutMonth == currentMonth && workoutYear == currentYear else {
                    return false
                }
                
                let distanceInMiles = workout.distance / 1609.34 // Convert meters to miles
                let paceInMinutesPerMile = (workout.pace ?? 0) / 60 // Convert seconds per km to minutes per mile
                
                switch workout.type {
                case .running:
                    return distanceInMiles >= 2.0 && paceInMinutesPerMile <= 12.0
                case .cycling:
                    return distanceInMiles >= 6.0 && paceInMinutesPerMile <= 4.0
                default:
                    return false
                }
            }.count

            print("Qualifying workouts count: \(qualifyingWorkoutsCount)")
        }

    // Fetch the current investment for the month
    func fetchInvestmentsForCurrentMonth() {
            guard let userId = Auth.auth().currentUser?.uid else {
                print("No authenticated user found")
                isLoading = false
                return
            }

            let db = Firestore.firestore()
            db.collection("Investments")
                .whereField("userId", isEqualTo: userId)
                .whereField("month", isEqualTo: currentMonthYear)
                .getDocuments { (querySnapshot, error) in
                    if let error = error {
                        print("Error getting documents: \(error)")
                        isLoading = false
                        return
                    }

                    let fetchedInvestments = querySnapshot?.documents.compactMap { document -> Investment? in
                        let data = document.data()
                        return Investment(
                            id: document.documentID,
                            amount: data["amount"] as? Double ?? 0.0,
                            contestId: data["contestId"] as? String,
                            month: data["month"] as? String ?? "Unknown",
                            timestamp: (data["timestamp"] as? Timestamp)?.dateValue(),
                            userId: data["userId"] as? String ?? "",
                            status: data["status"] as? String ?? "Unknown",
                            workoutCount: data["workoutCount"] as? Int ?? 0,
                            bonusRate: data["bonusRate"] as? Double ?? 0.0,
                            bonusSquares: data["bonusSquares"] as? Int ?? 0
                        )
                    } ?? []

                    DispatchQueue.main.async {
                        self.currentMonthInvestments = fetchedInvestments
                        self.isLoading = false
                        self.updateQualifyingWorkoutsCount()
                        print("Fetched \(self.currentMonthInvestments.count) investments.")
                    }
                }
        }





    
    private func earningsContent(for investment: Investment) -> some View {
        VStack(alignment: .leading, spacing: 8) {
            Text("Earnings")
                .font(.title3)
                .fontWeight(.bold)

            HStack(spacing: 15) {
                VStack {
                    Text("Earned")
                        .font(.subheadline)
                        .foregroundColor(.gray)
                    Spacer()
                    Text("$\(Int(totalEarnedAmount(for: investment)))")
                        .font(.title3)
                        .fontWeight(.bold)
                }
                .frame(maxWidth: .infinity, minHeight: 50)
                .padding()
                .background(RoundedRectangle(cornerRadius: 10).fill(Color.gray.opacity(0.2)))

                VStack {
                    Text("Potential")
                        .font(.subheadline)
                        .foregroundColor(.gray)
                    Spacer()
                    Text("$\(Int(possibleAmount(for: investment)))")
                        .font(.title3)
                        .fontWeight(.bold)
                }
                .frame(maxWidth: .infinity, minHeight: 50)
                .padding()
                .background(RoundedRectangle(cornerRadius: 10).fill(Color.gray.opacity(0.2)))
            }
        }
    }

    
    private func progressContent(for investment: Investment) -> some View {
            VStack(alignment: .leading) {
                Text("Progress")
                    .font(.title3)
                    .fontWeight(.bold)

                LazyVGrid(columns: columns, spacing: 5) {
                    ForEach(0..<investment.workoutCount, id: \.self) { index in
                        ZStack {
                            RoundedRectangle(cornerRadius: 5)
                                .fill(index < qualifyingWorkoutsCount ? Color.green : (index >= (investment.workoutCount - investment.bonusSquares) ? Color.orange.opacity(0.3) : Color.gray.opacity(0.3)))
                                .frame(height: 50)

                            let baseAmount = Int(investment.amount / Double(investment.workoutCount - investment.bonusSquares))
                            let bonusAmount = Int(investment.amount * (investment.bonusRate / 100.0) / Double(investment.bonusSquares))

                            Text(index < investment.workoutCount - investment.bonusSquares ? "$\(baseAmount)" : "+$\(bonusAmount)")
                                .font(.body)
                                .fontWeight(.bold)
                                .foregroundColor(index < qualifyingWorkoutsCount ? .white : .black)
                        }
                        .onTapGesture {
                            if index < qualifyingWorkoutsCount, index < completedWorkouts.count {
                                selectedWorkout = completedWorkouts[index]
                                showingWorkoutDetail = true
                            }
                        }
                    }
                }
            }
        }

   




}

extension DetailedWorkout: Equatable {
    static func == (lhs: DetailedWorkout, rhs: DetailedWorkout) -> Bool {
        // Implement equality check based on your DetailedWorkout properties
        // This is a basic example, adjust according to your actual properties
        return lhs.id == rhs.id && lhs.date == rhs.date
    }
}
