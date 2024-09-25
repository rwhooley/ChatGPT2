//
//  HomePersonalView.swift
//  ChatGPT2
//
//  Created by Ryan Whooley on 9/17/24.
//

import SwiftUI

struct HomePersonalView: View {
    @Binding var activeInvestment: Investment?
    @Binding var completedWorkouts: [DetailedWorkout]
    @Binding var selectedWorkout: DetailedWorkout?
    @Binding var showingWorkoutDetail: Bool
    
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
        VStack(alignment: .leading, spacing: 20) {
            HStack {
                Text(currentMonthYear)
                    .font(.title2)
                    .fontWeight(.bold)

                Button(action: {
                    // Show an explanation or helper view
                }) {
                    Image(systemName: "questionmark.circle")
                        .font(.title3)
                        .foregroundColor(.gray)
                }
            }

            Text(activeInvestment != nil ? "Active Investment" : "No Active Investment. Make a deposit to invest.")
                .foregroundColor(activeInvestment != nil ? .green : .gray)
                .font(.headline)

            earningsContent
            progressContent
        }
    }
    
    private var earningsContent: some View {
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
                    Text("$\(Int(totalEarnedAmount))")
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
                    Text("$\(Int(possibleAmount))")
                        .font(.title3)
                        .fontWeight(.bold)
                }
                .frame(maxWidth: .infinity, minHeight: 50)
                .padding()
                .background(RoundedRectangle(cornerRadius: 10).fill(Color.gray.opacity(0.2)))
            }
        }
    }
    
    private var progressContent: some View {
        VStack(alignment: .leading) {
            Text("Progress")
                .font(.title3)
                .fontWeight(.bold)

            LazyVGrid(columns: columns, spacing: 5) {
                ForEach(0..<12, id: \.self) { index in
                    ZStack {
                        RoundedRectangle(cornerRadius: 5)
                            .fill(index < completedSquares ? Color.green : (index >= 10 ? Color.orange.opacity(0.3) : Color.gray.opacity(0.3)))
                            .frame(height: 50)
                        
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
    }
}
