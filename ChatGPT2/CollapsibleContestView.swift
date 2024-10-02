//
//  CollapsibleContestView.swift
//  ChatGPT2
//
//  Created by Ryan Whooley on 9/20/24.
//

import SwiftUI
import Firebase
import FirebaseAuth

struct CollapsibleContestRow: View {
    let contest: Contest
    @State private var isExpanded = false
    @State private var creatorEmail: String = "Fetching..."
    @State private var isProcessing = false  // To handle invest button state
    @State private var userHasInvested = false  // Track if the user has already invested
    @State private var showCancelConfirmation = false // To show the confirmation dialog
    @Binding var contests: [Contest]
    
    var declineAction: () -> Void
    
    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            Button(action: { isExpanded.toggle() }) {
                contestHeader
            }
            .buttonStyle(PlainButtonStyle())

            if isExpanded {
                expandedContent
            }
        }
        .onAppear {
            fetchCreatorEmail(userId: contest.createdBy ?? "")
            
            // Check if the user has already invested
            checkIfUserHasInvested { hasInvested in
                self.userHasInvested = hasInvested
            }
        }
        .alert(isPresented: $showCancelConfirmation) {
                    Alert(
                        title: Text("Are you sure?"),
                        message: Text("Are you sure you want to cancel this contest? All funds will be returned to participants."),
                        primaryButton: .destructive(Text("Cancel Contest")) {
                            cancelContest() // If confirmed, cancel the contest
                        },
                        secondaryButton: .cancel(Text("Go Back"))
                    )
                }
        .padding()
        .background(RoundedRectangle(cornerRadius: 15)
            .fill(contest.status == "Pending" ? Color.yellow.opacity(0.1) : Color.green.opacity(0.1))
            .shadow(color: Color.gray.opacity(0.2), radius: 5, x: 0, y: 2))
        .overlay(
            RoundedRectangle(cornerRadius: 15)
                .stroke(contest.status == "Pending" ? Color.yellow.opacity(0.3) : Color.green.opacity(0.3), lineWidth: 1)
        )
    }
    
    private var contestHeader: some View {
        HStack {
            Text(contest.contestName)  // Ensure this is a non-optional field in the Contest model
                .font(.headline)
            Spacer()
            Text("\(formatCurrency(contest.totalPot ?? 0.0))")  // Safely unwrap totalPot
                .font(.subheadline)
            Image(systemName: isExpanded ? "chevron.up" : "chevron.down")
        }
    }


    private var expandedContent: some View {
        VStack(alignment: .leading, spacing: 8) {
            infoRow(title: "Group Members", value: contest.members.joined(separator: ", "))
            infoRow(title: "Created by", value: creatorEmail)
            infoRow(title: "Workout Type", value: contest.workoutType)
            infoRow(title: "Number of Workouts", value: "\(contest.numberOfWorkouts)")
            infoRow(title: "Distance Required", value: "\(contest.distance) miles")
            infoRow(title: "Pace Required", value: "\(contest.pace) min/mile")
            infoRow(title: "Timeframe", value: contest.timeframe)
            infoRow(title: "Start Date", value: formatDate(contest.startDate))
            infoRow(title: "End Date", value: formatDate(contest.endDate))
            infoRow(title: "Your Investment", value: formatCurrency(contest.investmentAmount))
            infoRow(title: "Payout Type", value: formatPayoutType(contest))

            if contest.status == "Pending" && !userHasInvested {
                actionButtons
            } else if contest.status == "Pending" && userHasInvested {
                Text("You have invested in this contest. Waiting for others to invest.")
                    .font(.subheadline)
                    .foregroundColor(.green)
            }
            
            if contest.status == "Pending" && Auth.auth().currentUser?.uid == contest.createdBy {
                        Button(action: cancelContest) {
                            Text("Cancel Contest")
                                .font(.headline)
                                .foregroundColor(.white)
                                .frame(maxWidth: .infinity)
                                .padding()
                                .background(Color.red)
                                .cornerRadius(10)
                        }
                        .padding(.top, 8)
                    }
            
        }
        .font(.subheadline)
    }

    private func cancelContest() {
        guard let currentUserId = Auth.auth().currentUser?.uid, currentUserId == contest.createdBy else {
            print("Only the contest creator can cancel the contest.")
            return
        }

        let db = Firestore.firestore()
        let contestRef = db.collection("contests").document(contest.id)

        isProcessing = true

        // Start a Firestore transaction to cancel the contest
        db.runTransaction({ (transaction, errorPointer) -> Any? in
            let contestSnapshot: DocumentSnapshot
            do {
                try contestSnapshot = transaction.getDocument(contestRef)
            } catch let error {
                errorPointer?.pointee = error as NSError
                return nil
            }

            // Ensure contest is still pending
            guard let status = contestSnapshot.data()?["status"] as? String, status == "Pending" else {
                print("Contest is no longer pending and cannot be canceled.")
                errorPointer?.pointee = NSError(domain: "AppErrorDomain", code: 0, userInfo: [NSLocalizedDescriptionKey: "Contest cannot be canceled."])
                return nil
            }

            // Mark the contest for deletion
            transaction.deleteDocument(contestRef)
            
            // Return success (nil means no errors)
            return nil
        }) { (result, error) in
            if let error = error {
                print("Error cancelling contest: \(error.localizedDescription)")
            } else {
                // Once the contest is deleted, we refund the participants outside the transaction
                refundAllInvestments(for: contest)
                // Remove the contest from the UI by filtering it out from the list
                                contests.removeAll { $0.id == contest.id }
            }
            isProcessing = false
        }
    }


    private func refundAllInvestments(for contest: Contest) {
        let db = Firestore.firestore()

        // Fetch participants and refund their investments
        let participantsRef = db.collection("Investments").whereField("contestId", isEqualTo: contest.id)
        participantsRef.getDocuments { snapshot, error in
            guard let documents = snapshot?.documents else {
                print("No participants found.")
                return
            }

            for document in documents {
                let data = document.data()
                if let userId = data["userId"] as? String, let amount = data["amount"] as? Double {
                    refundInvestment(userId: userId, amount: amount)
                }
            }
        }
    }

    private func refundInvestment(userId: String, amount: Double) {
        let userRef = Firestore.firestore().collection("users").document(userId)

        Firestore.firestore().runTransaction { (transaction, errorPointer) -> Any? in
            let userDocument: DocumentSnapshot
            do {
                try userDocument = transaction.getDocument(userRef)
            } catch let error {
                errorPointer?.pointee = error as NSError
                return nil
            }

            // Fetch the user's current balances
            let currentInvestedBalance = userDocument.data()?["investedBalance"] as? Double ?? 0.0
            let currentFreeBalance = userDocument.data()?["freeBalance"] as? Double ?? 0.0

            // Update balances: subtract from investedBalance, add to freeBalance
            let newInvestedBalance = currentInvestedBalance - amount
            let newFreeBalance = currentFreeBalance + amount

            // Apply the updates in the transaction
            transaction.updateData([
                "investedBalance": newInvestedBalance,
                "freeBalance": newFreeBalance
            ], forDocument: userRef)

            return nil
        } completion: { (result, error) in
            if let error = error {
                print("Error refunding investment: \(error.localizedDescription)")
            } else {
                print("Refund successful for user \(userId)")
            }
        }
    }

    
    private var actionButtons: some View {
        HStack {
            Button(action: investInContest) {
                Text("Invest")
                    .font(.headline)
                    .foregroundColor(.white)
                    .frame(maxWidth: .infinity)
                    .padding()
                    .background(isProcessing ? Color.gray : Color.blue)
                    .cornerRadius(10)
            }
            .disabled(isProcessing)

            Button(action: declineAction) {
                Text("Decline")
                    .font(.headline)
                    .foregroundColor(.white)
                    .frame(maxWidth: .infinity)
                    .padding()
                    .background(Color.red)
                    .cornerRadius(10)
            }
        }
        .padding(.top, 8)
    }

    private func investInContest() {
        guard let currentUserId = Auth.auth().currentUser?.uid else {
            print("User is not logged in")
            return
        }

        isProcessing = true // Disable the button during the investment process

        let db = Firestore.firestore()
        let userRef = db.collection("users").document(currentUserId)
        let contestRef = db.collection("contests").document(contest.id)
        
        // Fetch user's current freeBalance and investedBalance
        userRef.getDocument { (snapshot, error) in
            if let document = snapshot, document.exists {
                let userData = document.data() ?? [:]
                print("User Data: \(userData)")  // Debugging output

                guard let freeBalance = userData["freeBalance"] as? Double else {
                    print("Error: Could not fetch user's free balance")
                    self.isProcessing = false
                    return
                }

                let investedBalance = userData["investedBalance"] as? Double ?? 0.0 // Fallback to 0.0 if not found
                let investmentAmount = contest.investmentAmount ?? 0.0

                // Check if user has enough freeBalance to invest
                if freeBalance >= investmentAmount {
                    // Proceed with Firestore transaction to update both user's balance and contest's invested participants
                    db.runTransaction { (transaction, errorPointer) -> Any? in
                        let contestDocument: DocumentSnapshot
                        let userDocument: DocumentSnapshot
                        
                        do {
                            try contestDocument = transaction.getDocument(contestRef)
                            try userDocument = transaction.getDocument(userRef)
                        } catch let error {
                            errorPointer?.pointee = error as NSError
                            return nil
                        }
                        
                        let currentInvestedParticipants = contestDocument.data()?["investedParticipants"] as? Int ?? 0
                        let totalParticipants = contestDocument.data()?["totalParticipants"] as? Int ?? 0
                        let totalPot = contestDocument.data()?["totalPot"] as? Double ?? 0.0

                        let updatedFreeBalance = freeBalance - investmentAmount
                        let updatedInvestedBalance = investedBalance + investmentAmount
                        let updatedInvestedParticipants = currentInvestedParticipants + 1
                        let updatedTotalPot = totalPot + investmentAmount

                        // Update investedParticipants and totalPot in the contest
                        transaction.updateData([
                            "investedParticipants": updatedInvestedParticipants,
                            "totalPot": updatedTotalPot
                        ], forDocument: contestRef)
                        
                        // Update user's freeBalance and investedBalance
                        transaction.updateData([
                            "freeBalance": updatedFreeBalance,
                            "investedBalance": updatedInvestedBalance
                        ], forDocument: userRef)
                        
                        // Add a new investment record to the investments collection
                        let investmentData: [String: Any] = [
                            "userId": currentUserId,
                            "contestId": contest.id,
                            "amount": investmentAmount,
                            "timestamp": FieldValue.serverTimestamp()
                        ]
                        let newInvestmentRef = db.collection("Investments").document()
                        transaction.setData(investmentData, forDocument: newInvestmentRef)
                        
                        // Check if all participants have invested and flip the status to "Active"
                        if updatedInvestedParticipants == totalParticipants {
                            transaction.updateData(["status": "Active"], forDocument: contestRef)
                        }
                        
                        return nil
                    } completion: { (_, error) in
                        if let error = error {
                            print("Error in transaction: \(error.localizedDescription)")
                        } else {
                            print("Investment successful and contest status updated if fully invested")
                            self.userHasInvested = true // Update state to reflect investment
                        }
                        self.isProcessing = false // Re-enable the button after completion
                    }
                } else {
                    print("Insufficient free balance to invest")
                    self.isProcessing = false // Re-enable the button if balance is insufficient
                }

            } else {
                print("Error: Could not fetch user data or document does not exist")
                self.isProcessing = false
            }
        }
    }





    
    private func infoRow(title: String, value: String) -> some View {
        HStack(alignment: .top) {
            Text(title + ":")
                .foregroundColor(.secondary)
                .frame(width: 120, alignment: .leading)
            Text(value)
                .foregroundColor(.primary)
        }
    }

    // Fetch the email of the creator using their user ID
    private func fetchCreatorEmail(userId: String) {
        let db = Firestore.firestore()
        let userRef = db.collection("users").document(userId)
        
        userRef.getDocument { (document, error) in
            if let document = document, document.exists {
                self.creatorEmail = document.data()?["email"] as? String ?? "Unknown"
            } else {
                self.creatorEmail = "Unknown"
            }
        }
    }
    
    // Check if the current user has already invested in this contest
    private func checkIfUserHasInvested(completion: @escaping (Bool) -> Void) {
        guard let currentUserId = Auth.auth().currentUser?.uid else {
            completion(false)
            return
        }
        
        let investmentsRef = Firestore.firestore().collection("Investments")
            .whereField("userId", isEqualTo: currentUserId)
            .whereField("contestId", isEqualTo: contest.id)
        
        investmentsRef.getDocuments { (snapshot, error) in
            if let snapshot = snapshot, !snapshot.documents.isEmpty {
                completion(true)
            } else {
                completion(false)
            }
        }
    }
    
    private func formatPayoutType(_ contest: Contest) -> String {
        if contest.payoutType == "podium" {
            var payoutDetails = "Podium (1st: \(formatCurrency(contest.firstPlacePayout ?? 0.0))"
            if let secondPayout = contest.secondPlacePayout {
                payoutDetails += ", 2nd: \(formatCurrency(secondPayout))"
            }
            if let thirdPayout = contest.thirdPlacePayout {
                payoutDetails += ", 3rd: \(formatCurrency(thirdPayout))"
            }
            payoutDetails += ")"
            return payoutDetails
        } else {
            return "Prorate"
        }
    }


    private func formatDate(_ date: Date) -> String {
        let formatter = DateFormatter()
        formatter.dateStyle = .medium
        formatter.timeStyle = .none
        return formatter.string(from: date)
    }
    
    private func formatCurrency(_ amount: Double) -> String {
        let formatter = NumberFormatter()
        formatter.numberStyle = .currency
        formatter.currencyCode = "USD"
        return formatter.string(from: NSNumber(value: amount)) ?? "$0.00"
    }
}


