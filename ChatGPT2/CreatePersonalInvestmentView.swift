//
//  CreatePersonalInvestmentView.swift
//  ChatGPT2
//
//  Created by Ryan Whooley on 9/30/24.
//

//
//  CreatePersonalInvestmentView.swift
//  ChatGPT2
//
//  Created by Ryan Whooley on 9/30/24.
//

import SwiftUI
import Charts
import FirebaseFirestore
import FirebaseAuth

struct CreatePersonalInvestmentView: View {
    @Environment(\.presentationMode) var presentationMode
    @State private var selectedMonthYear = ""
    @State private var selectedWorkoutCount = 4
    @State private var selectedInvestmentAmount: Double = 20.0
    @State private var selectedPerWorkoutAmount: Double = 5.0
    @State private var isPerWorkoutSelected = false // Toggle for selecting total vs per workout
    @State private var showAlert = false
    @State private var alertMessage = ""
    
    // New logic to create months with years
    let workoutOptions = [4, 8, 12, 16]
    let investmentAmounts: [Double] = [1, 2, 3, 4, 5, 10, 15, 20, 25, 30, 40, 50, 75, 100, 200, 500, 1000]
    let perWorkoutOptions: [Double] = [1, 2, 3, 4, 5, 10, 15, 20, 25, 30, 40, 50, 75, 100]
   

    
    // Generate future month-year combinations for the next 24 months
    var monthsWithYears: [String] {
        var results = [String]()
        let currentMonth = Calendar.current.component(.month, from: Date())
        let currentYear = Calendar.current.component(.year, from: Date())
        let dateFormatter = DateFormatter()
        dateFormatter.dateFormat = "MMMM yyyy"
        
        for i in 0..<12 { // Next 24 months
            if let futureDate = Calendar.current.date(byAdding: .month, value: i, to: Date()) {
                let monthYearString = dateFormatter.string(from: futureDate)
                results.append(monthYearString)
            }
        }
        return results
    }
    
    var body: some View {
        VStack {
            Text("Create Personal Investment")
                .font(.title)
                .padding()
            
            Form {
                // Select Month-Year Picker
                VStack(alignment: .leading) {
                    Text("Investment Month")
                        .font(.headline)
                        .padding(.top)
                    Picker("Month", selection: $selectedMonthYear) {
                        Text("Select a month").tag("") // Placeholder
                        ForEach(monthsWithYears, id: \.self) { option in
                            Text(option)
                        }
                    }
                    .pickerStyle(MenuPickerStyle())
                    .padding()
                }
                // Number of Workouts Section with aligned label
                VStack(alignment: .leading) {
                    Text("Number of Workouts")
                        .font(.headline)
                        .padding(.top)

                    Text("Qualifying workouts are Runs >2 miles and <12 minutes per mile and Cycling >6 miles and <4 minutes per mile.")
                        .font(.caption)
                        .padding(.top)
                    
                    Picker("", selection: $selectedWorkoutCount) {
                        ForEach(workoutOptions, id: \.self) { option in
                            Text("\(option)")
                        }
                    }
                    .pickerStyle(SegmentedPickerStyle())
                    .padding()

                    // Display the bonus percentage text under the picker
                    Text("Potential Bonus: \(Int(bonusPercentageForWorkout(selectedWorkoutCount)))%")
                        .font(.caption)
                        .padding(.bottom, 10)
                }

                VStack(alignment: .leading) {
                    Text("Investment Amount")
                        .font(.headline)
                        .padding(.top)
                    // Toggle between total investment and per workout amount
                    Picker(selection: $isPerWorkoutSelected, label: Text("")) {
                        Text("Total Amount").tag(false)
                        Text("Per Workout Amount").tag(true)
                    }
                    .pickerStyle(SegmentedPickerStyle())
                    .padding()
                    
                    if isPerWorkoutSelected {
                        // Per Workout Amount
                        Picker("Per Workout Investment", selection: $selectedPerWorkoutAmount) {
                            ForEach(perWorkoutOptions, id: \.self) { amount in
                                Text("$\(amount, specifier: "%.0f")")
                            }
                        }
                        .pickerStyle(MenuPickerStyle())
                        .padding()
                    } else {
                        // Total Investment Amount
                        Picker("Total Investment", selection: $selectedInvestmentAmount) {
                            ForEach(investmentAmounts, id: \.self) { amount in
                                Text("$\(amount, specifier: "%.0f")")
                            }
                        }
                        .pickerStyle(MenuPickerStyle())
                        .padding()
                    }
                }

                // Dynamic Workout Grid View
                dynamicWorkoutGrid()
                    .padding()

                // Show Potential Earnings
                potentialEarningsView()
                    .padding()
            }
//            Spacer()
            // Create Investment Button
            Button(action: {
                            createInvestment()
                        }) {
                            Text("Create Investment")
                                .font(.headline)
                                .foregroundColor(.white)
                                .frame(maxWidth: .infinity)
                                .padding()
                                .background(Color.blue)
                                .cornerRadius(10)
                        }
                        .padding()
                    }
                    .alert(isPresented: $showAlert) {
                        Alert(
                            title: Text("Investment Status"),
                            message: Text(alertMessage),
                            dismissButton: .default(Text("OK")) {
                                // Dismiss the view if the investment is successfully created
                                if alertMessage == "Your investment has been successfully created!" {
                                    presentationMode.wrappedValue.dismiss()
                                }
                            }
                        )
                    }
                }

    // Helper function for bonus percentage based on workout count
    private func bonusPercentageForWorkout(_ workouts: Int) -> Double {
        switch workouts {
        case 4: return 0.0
        case 8: return 10.0
        case 12: return 20.0
        case 16: return 25.0
        default: return 0.0
        }
    }

    // Helper function for max bonus based on workout count
    private func maxBonusForWorkout(_ workouts: Int) -> Double {
        switch workouts {
        case 8: return 100.0
        case 12: return 300.0
        case 16: return 500.0
        default: return 0.0
        }
    }

    // Dynamic Workout Grid View with separate logic for total investment vs per workout
    private func dynamicWorkoutGrid() -> some View {
        let totalInvestment: Double
        let totalGreenSum: Double

        // Step 1: Determine the total green sum and total investment based on the selected investment type
        if isPerWorkoutSelected {
            // If "Per Workout Amount" is selected
            totalGreenSum = selectedPerWorkoutAmount * Double(selectedWorkoutCount - bonusSquaresCount(selectedWorkoutCount))
            totalInvestment = totalGreenSum
        } else {
            // If "Total Amount" is selected
            totalGreenSum = selectedInvestmentAmount
            totalInvestment = selectedInvestmentAmount
        }

        // Step 2: Calculate the total bonus based on the total investment or total green sum
        let totalBonus: Double
        if isPerWorkoutSelected {
            totalBonus = totalGreenSum * (bonusPercentageForWorkout(selectedWorkoutCount) / 100.0)
        } else {
            totalBonus = totalInvestment * (bonusPercentageForWorkout(selectedWorkoutCount) / 100.0)
        }

        // Step 3: Define how many green and yellow squares there are based on the selected workout count
        let (investmentSquares, bonusSquares): (Int, Int) = {
            switch selectedWorkoutCount {
            case 4: return (4, 0) // All investment, no bonus
            case 8: return (7, 1) // 7 investment, 1 bonus
            case 12: return (10, 2) // 10 investment, 2 bonus
            case 16: return (13, 3) // 13 investment, 3 bonus
            default: return (4, 0)
            }
        }()

        let totalSquares = selectedWorkoutCount // Define total number of squares

        // Step 4: Calculate the per-square bonus for yellow squares
        let bonusPerWorkout: Double = {
            switch selectedWorkoutCount {
            case 8: return totalBonus // 10% in the 8th yellow box
            case 12: return totalBonus / 2.0 // 20% split across 2 yellow boxes
            case 16: return totalBonus / 3.0 // 25% split across 3 yellow boxes
            default: return 0.0
            }
        }()

        // Step 5: Calculate the per-square investment for green squares
        let investmentPerWorkout: Double = {
            if isPerWorkoutSelected {
                return selectedPerWorkoutAmount
            } else {
                return totalGreenSum / Double(investmentSquares)
            }
        }()

        // Step 6: Display the dynamic grid with calculated values
        return VStack(alignment: .leading) {
            Text("Earnings per Workout")
                .font(.headline)
                .padding(.bottom, 5)

            // Create a grid based on the number of workouts
            LazyVGrid(columns: Array(repeating: GridItem(.flexible(), spacing: 10), count: 4), spacing: 10) {
                ForEach(0..<totalSquares, id: \.self) { index in
                    RoundedRectangle(cornerRadius: 10)
                        .fill(index < investmentSquares ? Color.green.opacity(0.5) : Color.yellow.opacity(0.5))
                        .frame(height: 50)
                        .overlay(
                            Text(index < investmentSquares ? "$\(investmentPerWorkout, specifier: "%.2f")" : "+$\(bonusPerWorkout, specifier: "%.2f")") // Display calculated amount per workout and bonus
                                .font(.headline)
                                .foregroundColor(.white)
                        )
                }
            }
        }
        .padding(.horizontal)
    }



    // Helper function to compute potential earnings based on selected workouts and investment
    private func potentialEarningsView() -> some View {
        // Calculate green box investment and potential bonus based on the selected investment type
        let greenBoxInvestment: Double
        let totalBonus: Double
        
        if isPerWorkoutSelected {
            // Per workout calculation
            greenBoxInvestment = selectedPerWorkoutAmount * Double(selectedWorkoutCount - bonusSquaresCount(selectedWorkoutCount))
            let bonusPercentage = bonusPercentageForWorkout(selectedWorkoutCount) / 100.0
            totalBonus = greenBoxInvestment * bonusPercentage
        } else {
            // Total amount calculation
            greenBoxInvestment = selectedInvestmentAmount
            let bonusPercentage = bonusPercentageForWorkout(selectedWorkoutCount) / 100.0
            totalBonus = min(greenBoxInvestment * bonusPercentage, maxBonusForWorkout(selectedWorkoutCount))
        }
        
        let totalPotentialEarnings = greenBoxInvestment + totalBonus
        
        // Bonus percentage label for the earnings section
        let bonusPercentageLabel: String = {
            switch selectedWorkoutCount {
            case 8: return "Bonus (10%)"
            case 12: return "Bonus (20%)"
            case 16: return "Bonus (25%)"
            default: return "Bonus (0%)"
            }
        }()
        
        return VStack {
            HStack {
                // Green rectangle for investment key
                RoundedRectangle(cornerRadius: 10)
                    .fill(Color.green.opacity(0.5))
                    .frame(width: 20, height: 20)
                Text("Investment: ")
                Spacer()
                Text("$\(greenBoxInvestment, specifier: "%.2f")")
            }

            HStack {
                // Yellow rectangle for bonus key
                RoundedRectangle(cornerRadius: 10)
                    .fill(Color.yellow.opacity(0.5))
                    .frame(width: 20, height: 20)
                Text("\(bonusPercentageLabel): ")  // Display bonus percentage label
                Spacer()
                Text("$\(totalBonus, specifier: "%.2f")")
            }

            Divider()

            HStack {
                Text("Total Potential Earnings:")
                    .font(.headline)
                Spacer()
                Text("$\(totalPotentialEarnings, specifier: "%.2f")")
                    .font(.headline)
            }
            
                    
                
        }
        
        
        .padding()
        .background(Color(UIColor.secondarySystemBackground))
        .cornerRadius(10)
    }

    
    
    private func createInvestment() {
        // Ensure a month is selected
        guard !selectedMonthYear.isEmpty else {
            print("No month selected")
            alertMessage = "Please select a month"
            showAlert = true
            return
        }

        // Get the current user's userId
        guard let userId = Auth.auth().currentUser?.uid else {
            print("No authenticated user found")
            alertMessage = "You must be logged in to create an investment."
            showAlert = true
            return
        }

        print("Creating investment for userId: \(userId)")

        // Firestore reference
        let db = Firestore.firestore()

        // Calculate bonusRate and bonusSquares based on the selected workout count
        let bonusRate = bonusPercentageForWorkout(selectedWorkoutCount)
        let bonusSquares = bonusSquaresCount(selectedWorkoutCount)

        // Calculate the amount of investment
        let amount = isPerWorkoutSelected ? selectedPerWorkoutAmount * Double(selectedWorkoutCount) : selectedInvestmentAmount

        // Fetch the user balance before creating the investment
        let userRef = db.collection("users").document(userId)

        userRef.getDocument { (document, error) in
            if let error = error {
                print("Error fetching user document: \(error.localizedDescription)")
                alertMessage = "Error fetching user document: \(error.localizedDescription)"
                showAlert = true
                return
            }

            guard let document = document, document.exists else {
                print("User document does not exist for userId: \(userId)")
                alertMessage = "User document does not exist. Please ensure your account is set up correctly."
                showAlert = true
                return
            }

            guard let data = document.data(),
                  let freeBalance = data["freeBalance"] as? Double, // Fetching the correct free balance field
                  let investedBalance = data["investedBalance"] as? Double else { // Fetching the invested balance field
                print("Error fetching balance data") // If the balance data is not found, this error is printed
                alertMessage = "Error fetching balance data."
                showAlert = true
                return
            }

            print("User freeBalance: \(freeBalance), investedBalance: \(investedBalance)")

            // Check if the user has enough free balance to make the investment
            if freeBalance >= amount {
                // Data to be written to Firestore for the investment
                let investmentData: [String: Any] = [
                    "month": selectedMonthYear,
                    "investmentType": "Personal",
                    "workoutCount": selectedWorkoutCount,
                    "amount": amount,
                    "bonusRate": bonusRate,
                    "bonusSquares": bonusSquares,
                    "createdAt": Timestamp(date: Date()),
                    "userId": userId
                ]

                // Create the investment
                db.collection("Investments").addDocument(data: investmentData) { error in
                    if let error = error {
                        print("Error creating investment: \(error.localizedDescription)")
                        alertMessage = "Error creating investment: \(error.localizedDescription)"
                        showAlert = true
                        return
                    }

                    // Update user's free and invested balances
                    let newFreeBalance = freeBalance - amount
                    let newInvestedBalance = investedBalance + amount

                    userRef.updateData([
                        "freeBalance": newFreeBalance, // Update the free balance field
                        "investedBalance": newInvestedBalance // Update the invested balance field
                    ]) { error in
                        if let error = error {
                            print("Error updating user balances: \(error.localizedDescription)")
                            alertMessage = "Error updating balances: \(error.localizedDescription)"
                        } else {
                            print("Investment created successfully and balances updated")
                            alertMessage = "Your investment has been successfully created!"
                        }
                        showAlert = true
                    }
                }
            } else {
                print("Insufficient free balance")
                alertMessage = "You don't have enough free balance to make this investment."
                showAlert = true
            }
        }

    }





    private func bonusSquaresCount(_ workouts: Int) -> Int {
        switch workouts {
        case 4: return 0 // No bonus squares for 4 workouts
        case 8: return 1 // 1 bonus square for 8 workouts
        case 12: return 2 // 2 bonus squares for 12 workouts
        case 16: return 3 // 3 bonus squares for 16 workouts
        default: return 0
        }
    }


   }

#Preview {
    CreatePersonalInvestmentView()
}
