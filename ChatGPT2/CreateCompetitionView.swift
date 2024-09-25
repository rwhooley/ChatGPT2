//
//  CreateCompetitionView.swift
//  ChatGPT2
//
//  Created by Ryan Whooley on 9/12/24.
//

import SwiftUI
import FirebaseAuth  // Assuming you are using Firebase for authentication
import FirebaseFirestore

enum PayoutType: String, CaseIterable {
    case podium  // First to finish all workouts wins
    case prorate  // Everyone who completes gets their money prorated
}


struct CreateCompetitionView: View {
    @State private var contestName: String = ""  // For contest name
    @State private var selectedWorkoutType: String = "Running"  // Picker for workout types
    @State private var distance: Double? = nil
    @State private var pace: Double? = nil
    @State private var numberOfWorkouts: Int = 5
    @State private var timeframe: TimeFrame = .oneWeek
    @State private var startDate: Date = Date()  // Field for picking the start date
    @State private var investmentAmount: String = "5"  // Use String for "Other" entry
    @State private var otherInvestmentAmount: Double? = nil  // Store custom "Other" amount
    @State private var payoutType: PayoutType = .podium
    @State private var payoutDistribution: [Double] = [50, 35, 15]  // Default podium payout
    @State private var members: [String] = []  // Store group member names
    @State private var searchText: String = ""  // For searching friends

    @State private var competeOn: CompeteOn = .speed  // New field for competition type
    @State private var userEmail: String = ""  // Current user's email
    
    @State private var showErrorMessage: Bool = false  // To control error display
    @State private var errorMessage: String = ""  // Error message text
    @State private var isValidEmail: Bool = true  // To control email validation result
    
    
    // Add state for payout inputs
    @State private var firstPlacePayout: Double = 0.0
    @State private var secondPlacePayout: Double = 0.0
    @State private var thirdPlacePayout: Double = 0.0
    
    @State private var showReviewSheet: Bool = false  // Controls showing the popover
    @State private var showConfirmationAlert: Bool = false  // Controls the confirmation alert
    @State private var isContestCreated: Bool = false  // Track if contest was created successfully
    @State private var isLoading: Bool = false  // To show a loading indicator
    
    @State private var showSuccessAlert: Bool = false
    @State private var isContestCreatedSuccessfully: Bool = false
      
    @EnvironmentObject var alertManager: AlertManager
    
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

    enum CompeteOn: String, CaseIterable {
        case speed = "Speed"
        case completion = "Completion"
    }

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
    
    let workoutTypeOptions = ["Running", "Cycling"]
    let investmentOptions = ["5", "10", "25", "50", "100", "Other"]
    
    var totalPot: Double {
        guard let investment = Double(investmentAmount) ?? otherInvestmentAmount else { return 0 }
        return investment * Double(members.count)
    }
    
    // Function to calculate the remaining pot amount
    var remainingPot: Double {
        return totalPot - firstPlacePayout - secondPlacePayout - thirdPlacePayout
    }
    
    var body: some View {
        
        Spacer()
        Text("Start a competition with friends by entering details below. Compete against your friends to complete workouts and earn money!")
            .padding()
        
        VStack {
                // Display the error message if there is one
                if showErrorMessage {
                    Text(errorMessage)
                        .foregroundColor(.red)
                        .padding()
                }
        
        Form {
            // Contest Name Field
            Section(header: Text("Contest Name")) {
                TextField("Enter contest name", text: $contestName)
                    .textFieldStyle(RoundedBorderTextFieldStyle())
            }
            
            // Invite Group Members Section
            Section(header: Text("Invite Group Members")) {
                                HStack {
                                    TextField("Enter friend's email", text: $searchText, onCommit: addMember)
                                        .textFieldStyle(RoundedBorderTextFieldStyle())
                                    
                                    Button(action: {
                                        addMember()
                                    }) {
                                        Text("Add")
                                    }
                                }

                                // Show invalid email error
                                if !isValidEmail {
                                    Text("Email not found in the database.")
                                        .foregroundColor(.red)
                                        .font(.caption)
                                }
                
                // Display group members who have been added
                ForEach(members, id: \.self) { member in
                    Text(member)
                }
            }
            
            // Workout Types Section (Picker)
            Section(header: Text("Workout Type")) {
                Picker("Select workout type", selection: $selectedWorkoutType) {
                    ForEach(workoutTypeOptions, id: \.self) { workout in
                        Text(workout)
                    }
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
            
            // Starting On Section (New)
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
            
            // Investment Section
            Section(header: Text("Investment Per Person")) {
                Picker("Select Investment Amount", selection: $investmentAmount) {
                    ForEach(investmentOptions, id: \.self) { amount in
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
            
            // Payout Type Section with Conditional Sliders
                       Section(header: Text("Payout Type")) {
                           Picker("Payout Type", selection: $payoutType) {
                               ForEach(PayoutType.allCases, id: \.self) { payout in
                                   Text(payout.rawValue).tag(payout)
                               }
                           }
                           .pickerStyle(SegmentedPickerStyle())
                           
                           if payoutType == .podium {
                               VStack {
                                   HStack {
                                       Text("1st Place:")
                                       Stepper(value: $firstPlacePayout, in: 0...(totalPot - secondPlacePayout - thirdPlacePayout)) {
                                           Text("$\(firstPlacePayout, specifier: "%.2f")")
                                       }
                                   }
                                   
                                   if members.count > 1 {
                                       HStack {
                                           Text("2nd Place:")
                                           Stepper(value: $secondPlacePayout, in: 0...(totalPot - firstPlacePayout - thirdPlacePayout)) {
                                               Text("$\(secondPlacePayout, specifier: "%.2f")")
                                           }
                                       }
                                   }
                                   
                                   if members.count > 2 {
                                       HStack {
                                           Text("3rd Place:")
                                           Stepper(value: $thirdPlacePayout, in: 0...(totalPot - firstPlacePayout - secondPlacePayout)) {
                                               Text("$\(thirdPlacePayout, specifier: "%.2f")")
                                           }
                                       }
                                   }
                               }
                               
                               Text("Remaining Pot: $\(remainingPot, specifier: "%.2f")")
                                   .font(.footnote)
                                   .foregroundColor(remainingPot == 0 ? .green : .red)
                           }
                       }
                   

        }

            VStack {
//                Spacer()  // Pushes the content up
                
                Button(action: {
                                    if validateForm() {
                                        showReviewSheet.toggle()  // Show the review popover
                                    }
                                }) {
                    Text("Create Competition")
                        .fontWeight(.bold)
                        .frame(maxWidth: .infinity)  // Makes the text centered
                        .padding()
                        .background(Color.blue)  // Makes the button background blue
                        .foregroundColor(.white)  // Makes the text color white
                        .cornerRadius(10)  // Gives rounded corners
                }
                .padding(.horizontal)  // Adds padding around the button horizontally
            }
            .sheet(isPresented: $showReviewSheet) {
                        ReviewContestSheet(
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
                            payoutType: payoutType,  // Add this line
                            firstPlacePayout: firstPlacePayout,
                            secondPlacePayout: secondPlacePayout,
                            thirdPlacePayout: thirdPlacePayout,
                            members: members,
                            isLoading: $isLoading,
                            goBack: {
                                showReviewSheet = false
                            },
                            create: { completion in
                                createContest { success in
                                    print("Contest creation result: \(success)") // Debug log
                                    if success {
                                        self.isContestCreatedSuccessfully = true
                                        completion(true)
                                    } else {
                                        completion(false)
                                    }
                                }
                            }
                        )
                    }
            .onChange(of: showReviewSheet) { isPresented in
                            if !isPresented && isContestCreatedSuccessfully {
                                print("Review sheet dismissed, contest created successfully") // Debug log
                                DispatchQueue.main.asyncAfter(deadline: .now() + 0.5) {
                                    self.showSuccessAlert = true
                                    print("Setting showSuccessAlert to true") // Debug log
                                }
                                isContestCreatedSuccessfully = false
                            }
                        }
            
            .alert(isPresented: $showSuccessAlert) {
                            Alert(
                                title: Text("Success!"),
                                message: Text("Your contest has been created."),
                                dismissButton: .default(Text("OK"))
                            )
                        }
                    
            
                    }
                    .onAppear {
                        fetchUserEmail()
                    }
                }

    // Function to create the contest in Firestore
    private func createContest(completion: @escaping (Bool) -> Void) {
        guard let userId = Auth.auth().currentUser?.uid else {
            completion(false)
            return
        }
        let db = Firestore.firestore()
        let contestData: [String: Any] = [
                "contestName": contestName,
                "workoutType": selectedWorkoutType,
                "distance": distance ?? 0,
                "pace": pace ?? 0,
                "numberOfWorkouts": numberOfWorkouts,
                "timeframe": timeframe.rawValue,
                "startDate": startDate,
                "endDate": endDate,
                "investmentAmount": investmentAmount == "Other" ? otherInvestmentAmount ?? 0 : Double(investmentAmount) ?? 0,
                "totalPot": totalPot,
                "payoutType": payoutType.rawValue,
                "firstPlacePayout": firstPlacePayout,
                "secondPlacePayout": secondPlacePayout,
                "thirdPlacePayout": thirdPlacePayout,
                "status": "Pending",
                "createdBy": userId,
                "createdAt": FieldValue.serverTimestamp(),
                "totalParticipants": members.count,
                "investedParticipants": 0,
                "members": members  // Add this line to include the list of members
            ]
            
            isLoading = true
            
            db.collection("contests").addDocument(data: contestData) { error in
                if let error = error {
                    print("Error creating contest: \(error)")
                    self.errorMessage = "Failed to create contest. Please try again."
                    self.showErrorMessage = true
                    self.isLoading = false
                    completion(false)
                } else {
                    // Contest created successfully, now create investment documents for each participant
                    let contestRef = db.collection("contests").document()
                    let batch = db.batch()
                    
                    for member in self.members {
                        let investmentRef = contestRef.collection("investments").document(member)
                        let investmentData: [String: Any] = [
                            "userId": member,
                            "email": member,
                            "investmentAmount": self.investmentAmount == "Other" ? self.otherInvestmentAmount ?? 0 : Double(self.investmentAmount) ?? 0,
                            "investmentStatus": "Pending",
                            "investedAt": NSNull()
                        ]
                        batch.setData(investmentData, forDocument: investmentRef)
                    }
                    
                    batch.commit { error in
                        DispatchQueue.main.async {
                            self.isLoading = false
                            if let error = error {
                                print("Error creating investments: \(error)")
                                self.errorMessage = "Failed to create investments. Please try again."
                                self.showErrorMessage = true
                                completion(false)
                            } else {
                                print("Contest and investments successfully created!")
                                self.isContestCreatedSuccessfully = true
                                completion(true)
                            }
                        }
                    }
                }
            }
        }
       

    
    // Function to check if the email exists in the database and add member
    private func addMember() {
        // Clean and standardize email input (trim spaces and lowercase)
        let cleanedEmail = searchText.trimmingCharacters(in: .whitespacesAndNewlines).lowercased()

        guard !cleanedEmail.isEmpty else {
            isValidEmail = false
            errorMessage = "Please enter an email address."
            showErrorMessage = true
            return
        }

        // Reset error states before querying
        isValidEmail = true
        errorMessage = ""
        showErrorMessage = false

        // Firestore query to check if the email exists in the 'users' collection
        let db = Firestore.firestore()
        db.collection("users")
            .whereField("email", isEqualTo: cleanedEmail)  // Querying the exact 'email' field
            .getDocuments { (querySnapshot, error) in
                if let error = error {
                    print("Error fetching documents: \(error)")
                    self.isValidEmail = false
                    self.errorMessage = "Error fetching user from Firestore."
                    self.showErrorMessage = true
                } else {
                    if let documents = querySnapshot?.documents {
                        if !documents.isEmpty {
                            // Email exists, add member
                            print("Email found: \(cleanedEmail)")
                            if !self.members.contains(cleanedEmail) {
                                self.members.append(cleanedEmail)
                                self.searchText = ""  // Clear search field
                                self.isValidEmail = true  // Reset error flag
                                self.errorMessage = ""  // Clear error message
                            }
                        } else {
                            // No document found for the entered email
                            print("Email not found in Firestore: \(cleanedEmail)")
                            self.isValidEmail = false
                            self.errorMessage = "Email not found in the database."
                            self.showErrorMessage = true
                        }
                    } else {
                        // No documents were found
                        print("No documents found for query: \(cleanedEmail)")
                        self.isValidEmail = false
                        self.errorMessage = "Email not found in the database."
                        self.showErrorMessage = true
                    }
                }
            }
    }

    
   
    
    // Function to validate the form before allowing submission
        private func validateForm() -> Bool {
            // Check if all required fields are filled
            if contestName.isEmpty || members.isEmpty || selectedWorkoutType.isEmpty || distance == nil || pace == nil || investmentAmount.isEmpty || (investmentAmount == "Other" && otherInvestmentAmount == nil) {
                errorMessage = "Please complete all fields before proceeding."
                showErrorMessage = true
                return false
            }

            // Check if total pot is fully allocated in podium payout type
            if payoutType == .podium && remainingPot != 0 {
                errorMessage = "Please allocate the entire pot to the winners."
                showErrorMessage = true
                return false
            }

            showErrorMessage = false
            return true
        }

    
    // Function to fetch the current user's email
    private func fetchUserEmail() {
        if let currentUser = Auth.auth().currentUser {
            userEmail = currentUser.email ?? ""
            members.append(userEmail)  // Automatically add the user's email to the group
        }
    }

}

// Popover View to Review Contest Details
struct ReviewContestSheet: View {
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
    var payoutType: PayoutType
    var firstPlacePayout: Double
    var secondPlacePayout: Double
    var thirdPlacePayout: Double
    var members: [String]
    
    @Binding var isLoading: Bool
    
    var goBack: () -> Void
    var create: (@escaping (Bool) -> Void) -> Void
    
    @Environment(\.presentationMode) var presentationMode
    
    var body: some View {
        VStack {
            Text("Review Competition Details")
                .font(.headline)
                .padding()
            
            ScrollView {
                VStack(alignment: .leading, spacing: 10) {
                    Text("Competition Name: \(contestName)")
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
                    
                    Text("Payout Information:")
                                if payoutType == .podium {
                                    if members.count >= 3 {
                                        Text("1st Place: $\(firstPlacePayout, specifier: "%.2f")")
                                        Text("2nd Place: $\(secondPlacePayout, specifier: "%.2f")")
                                        Text("3rd Place: $\(thirdPlacePayout, specifier: "%.2f")")
                                    } else if members.count == 2 {
                                        Text("1st Place: $\(firstPlacePayout, specifier: "%.2f")")
                                        Text("2nd Place: $\(secondPlacePayout, specifier: "%.2f")")
                                    }
                                } else {
                                    Text("Prorated Payout. Money will be paid out in proportion to number of workouts each user completes.")
                                }
                    
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

                Button(action: {
                    create { success in
                        print("Create button tapped, success: \(success)") // Debug log
                        if success {
                            DispatchQueue.main.async {
                                self.presentationMode.wrappedValue.dismiss()
                            }
                        }
                    }
                }) {
                    if isLoading {
                        ProgressView()
                    } else {
                        Text("Create")
                    }
                }
                .frame(maxWidth: .infinity)
                .padding()
                .background(Color.blue)
                .foregroundColor(.white)
                .cornerRadius(10)
                .disabled(isLoading)
                .padding(.horizontal)
            }
            .padding()
        }
        .frame(maxHeight: .infinity)
    }
}


#Preview {
    CreateCompetitionView()
}



