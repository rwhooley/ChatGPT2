//
//  CreateCollaborationView.swift
//  ChatGPT2
//
//  Created by Ryan Whooley on 9/12/24.
//

import SwiftUI
import FirebaseAuth

struct CreateCollaborationView: View {
    @State private var contestName: String = ""
    @State private var selectedWorkoutType: String = "Running"
    @State private var distance: Double? = nil
    @State private var pace: Double? = nil
    @State private var numberOfWorkouts: Int = 5
    @State private var timeframe: TimeFrame = .oneWeek
    @State private var startDate: Date = Date()  // Field for picking the start date
    @State private var investmentAmount: String = "5"
    @State private var otherInvestmentAmount: Double? = nil
    @State private var members: [String] = []  // Store group member names
    @State private var searchText: String = ""

    @State private var showReviewSheet: Bool = false  // Control for popover

    enum TimeFrame: String, CaseIterable {
        case oneDay = "1 Day"
        case threeDays = "3 Days"
        case fiveDays = "5 Days"
        case oneWeek = "1 Week"
        case twoWeeks = "2 Weeks"
        case oneMonth = "1 Month"
        case threeMonths = "3 Months"
        case sixMonths = "6 Months"
    }

    // Calculate the end date based on timeframe and start date
    var endDate: Date {
        var dateComponent = DateComponents()
        
        switch timeframe {
        case .oneDay:
            dateComponent.day = 1
        case .threeDays:
            dateComponent.day = 3
        case .fiveDays:
            dateComponent.day = 5
        case .oneWeek:
            dateComponent.day = 7
        case .twoWeeks:
            dateComponent.day = 14
        case .oneMonth:
            dateComponent.month = 1
        case .threeMonths:
            dateComponent.month = 3
        case .sixMonths:
            dateComponent.month = 6
        }
        
        return Calendar.current.date(byAdding: dateComponent, to: startDate) ?? startDate
    }

    var totalPot: Double {
        guard let investment = Double(investmentAmount) ?? otherInvestmentAmount else { return 0 }
        return investment * Double(members.count)
    }

    var body: some View {
        Spacer()
        Text("Start a collaboration with friends by entering details below. Hold eachother accountable to ensure you complete your workouts and don't lose money!")
            .padding()
        
        Form {
            // Contest Name Section
            Section(header: Text("Collaboration Name")) {
                TextField("Enter collaboration name", text: $contestName)
                    .textFieldStyle(RoundedBorderTextFieldStyle())
            }

            // Invite Group Members Section
            Section(header: Text("Invite Group Members")) {
                TextField("Enter friend's email", text: $searchText, onCommit: addMember)
                    .textFieldStyle(RoundedBorderTextFieldStyle())

                // Display group members who have been added
                ForEach(members, id: \.self) { member in
                    Text(member)
                }
            }

            // Workout Type Section (Picker)
            Section(header: Text("Workout Type")) {
                Picker("Select workout type", selection: $selectedWorkoutType) {
                    Text("Running").tag("Running")
                    Text("Cycling").tag("Cycling")
                }
                .pickerStyle(SegmentedPickerStyle())
            }

            // Number of Workouts Section
            Section(header: Text("Number of Workouts")) {
                Stepper("\(numberOfWorkouts)", value: $numberOfWorkouts, in: 1...30)
            }

            // Timeframe Section
            Section(header: Text("Timeframe")) {
                Picker("Timeframe", selection: $timeframe) {
                    ForEach(TimeFrame.allCases, id: \.self) { timeframe in
                        Text(timeframe.rawValue).tag(timeframe)
                    }
                }
            }

            // Starting On Section
            Section(header: Text("Starting On")) {
                DatePicker("Select start date", selection: $startDate, displayedComponents: .date)
                    .datePickerStyle(CompactDatePickerStyle())
                
                Text("End Date: \(endDate.formatted(date: .long, time: .omitted))")
                    .font(.footnote)
                    .foregroundColor(.gray)
            }

            // Workout Parameters Section
            Section(header: Text("Workout Parameters")) {
                HStack {
                    Text("Distance (miles):")
                    TextField("Enter distance", value: $distance, format: .number)
                        .keyboardType(.decimalPad)
                }

                HStack {
                    Text("Pace (min/mile):")
                    TextField("Enter pace", value: $pace, format: .number)
                        .keyboardType(.decimalPad)
                }
            }

            // Investment Per Person Section
            Section(header: Text("Investment Per Person")) {
                Picker("Select Investment Amount", selection: $investmentAmount) {
                    ForEach(["5", "10", "25", "50", "100", "Other"], id: \.self) { amount in
                        Text(amount == "Other" ? "Other" : "$\(amount)").tag(amount)
                    }
                }
                .pickerStyle(SegmentedPickerStyle())
                
                if investmentAmount == "Other" {
                    HStack {
                        Text("Enter amount:")
                        TextField("Custom amount", value: $otherInvestmentAmount, format: .number)
                            .keyboardType(.decimalPad)
                    }
                }
                
                // Display Total Pot
                if members.count > 0 {
                    Text("Total Pot: $\(totalPot, specifier: "%.2f")")
                        .font(.footnote)
                        .foregroundColor(.gray)
                }
            }

            // Create Collaboration Button
            VStack {
                Spacer()
                
                Button(action: {
                    showReviewSheet.toggle()
                }) {
                    Text("Create Collaboration")
                        .fontWeight(.bold)
                        .frame(maxWidth: .infinity)
                        .padding()
                        .background(Color.blue)
                        .foregroundColor(.white)
                        .cornerRadius(10)
                }
                .padding(.horizontal)
            }
        }
        .navigationTitle("Create Collaboration")
        .sheet(isPresented: $showReviewSheet) {
            ReviewCollaborationSheet(
                contestName: contestName,
                workoutType: selectedWorkoutType,
                distance: distance ?? 0,
                pace: pace ?? 0,
                numberOfWorkouts: numberOfWorkouts,
                timeframe: timeframe.rawValue,
                startDate: startDate,
                endDate: endDate,
                investmentAmount: investmentAmount,
                otherInvestmentAmount: otherInvestmentAmount,
                totalPot: totalPot,
                members: members,
                goBack: { showReviewSheet = false },
                create: createCollaboration
            )
        }
    }

    // Function to add members
    private func addMember() {
        if !searchText.isEmpty && !members.contains(searchText) {
            members.append(searchText)
            searchText = ""  // Clear the search text after adding
        }
    }

    // Function to handle the creation of the collaboration
    private func createCollaboration() {
        print("Collaboration Created")
        showReviewSheet = false  // Dismiss the review sheet after creation
    }
}

// Popover to review collaboration details
struct ReviewCollaborationSheet: View {
    var contestName: String
    var workoutType: String
    var distance: Double
    var pace: Double
    var numberOfWorkouts: Int
    var timeframe: String
    var startDate: Date
    var endDate: Date
    var investmentAmount: String
    var otherInvestmentAmount: Double?
    var totalPot: Double
    var members: [String]
    
    var goBack: () -> Void  // Go back action
    var create: () -> Void  // Create contest action
    
    var body: some View {
       VStack {
            Text("Please Review Collaboration Details")
                .font(.headline)
                .padding()
            
            ScrollView {
                VStack(alignment: .leading, spacing: 10) {
                    Text("Collaboration Name: \(contestName)")
                    Text("Workout Type: \(workoutType)")
                    Text("Distance: \(distance, specifier: "%.2f") miles")
                    Text("Pace: \(pace, specifier: "%.2f") min/mile")
                    Text("Number of Workouts: \(numberOfWorkouts)")
                    Text("Timeframe: \(timeframe)")
                    Text("Start Date: \(startDate.formatted(date: .long, time: .omitted))")
                    Text("End Date: \(endDate.formatted(date: .long, time: .omitted))")
                    
                    if investmentAmount == "Other" {
                        Text("Investment Per Person: $\(otherInvestmentAmount ?? 0, specifier: "%.2f")")
                    } else {
                        Text("Investment Per Person: $\(investmentAmount)")
                    }
                    
                    Text("Total Pot: $\(totalPot, specifier: "%.2f")")
                    
                    Text("Group Members:")
                    ForEach(members, id: \.self) { member in
                        Text("- \(member)")
                    }
                }
                .padding()
            }
            
            Spacer()
            
            HStack {
                Button(action: goBack) {
                    Text("Go Back")
                        .frame(maxWidth: .infinity)
                        .padding()
                        .background(Color.gray)
                        .foregroundColor(.white)
                        .cornerRadius(10)
                }
                .padding(.horizontal)

                Button(action: create) {
                    Text("Create")
                        .frame(maxWidth: .infinity)
                        .padding()
                        .background(Color.blue)
                        .foregroundColor(.white)
                        .cornerRadius(10)
                }
                .padding(.horizontal)
            }
            .padding()
        }
        .frame(maxHeight: .infinity)
    }
}

#Preview {
    CreateCollaborationView()
}
