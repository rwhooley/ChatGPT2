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
            checkIfUserHasInvested()  // Check if the user has already invested
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
            } else if userHasInvested {
                Text("You have already invested in this contest. Waiting for others to invest.")
                    .font(.subheadline)
                    .foregroundColor(.green)
            }
        }
        .font(.subheadline)
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
        // Add logic to handle the investment process here
        print("User is investing in the contest")
        // You can integrate Firebase code to process the user's investment here.
        guard let currentUserId = Auth.auth().currentUser?.uid else { return }

        // Update Firestore with investment details (adjust as needed)
        let db = Firestore.firestore()
        let contestRef = db.collection("contests").document(contest.id)
        
        contestRef.updateData(["investedParticipants": FieldValue.increment(Int64(1))]) { error in
            if let error = error {
                print("Error updating participants: \(error)")
            } else {
                print("Investment successful")
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
    private func checkIfUserHasInvested() {
        guard let currentUserId = Auth.auth().currentUser?.uid else { return }
        let investmentsRef = Firestore.firestore().collection("investments")
            .whereField("userId", isEqualTo: currentUserId)
            .whereField("contestId", isEqualTo: contest.id)
        
        investmentsRef.getDocuments { (snapshot, error) in
            if let snapshot = snapshot, !snapshot.documents.isEmpty {
                self.userHasInvested = true
            } else {
                self.userHasInvested = false
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


