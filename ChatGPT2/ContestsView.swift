////
////  ContestsView.swift
////  ChatGPT2
////
////  Created by Ryan Whooley on 9/16/24.
////
//
//import SwiftUI
//import FirebaseFirestore
//import FirebaseAuth
//
//@MainActor
//class ContestsViewModel: ObservableObject {
//    @Published var pendingContests: [Contest] = []
//    @Published var activeContests: [Contest] = []
//    @Published var isLoading = false
//    @Published var errorMessage: String?
//
//    func fetchContests() async {
//        guard let userEmail = Auth.auth().currentUser?.email else {
//            errorMessage = "User not logged in"
//            return
//        }
//
//        isLoading = true
//        defer { isLoading = false }
//
//        do {
//            let db = Firestore.firestore()
//            
//            // Fetch all contests the user is a member of
//            let snapshot = try await db.collection("contests")
//                .whereField("members", arrayContains: userEmail)
//                .getDocuments()
//
//            let allContests = snapshot.documents.compactMap { Contest(id: $0.documentID, data: $0.data()) }
//            pendingContests = allContests.filter { $0.status == "Pending" }
//            activeContests = allContests.filter { $0.status == "Active" }
//        } catch {
//            errorMessage = "Error fetching contests: \(error.localizedDescription)"
//        }
//    }
//
//    func declineContest(_ contest: Contest) async {
//        guard let userEmail = Auth.auth().currentUser?.email else {
//            errorMessage = "User not logged in"
//            return
//        }
//
//        let db = Firestore.firestore()
//        let contestRef = db.collection("contests").document(contest.id)
//        let investmentRef = contestRef.collection("investments").document(userEmail)
//
//        do {
//            try await db.runTransaction { transaction, _ in
//                transaction.updateData(["members": FieldValue.arrayRemove([userEmail])], forDocument: contestRef)
//                transaction.deleteDocument(investmentRef)
//                return nil // Add this return statement to fix the error
//            }
//            pendingContests.removeAll { $0.id == contest.id }
//            errorMessage = "Successfully declined the contest"
//        } catch {
//            errorMessage = "Failed to decline contest: \(error.localizedDescription)"
//        }
//    }
//
//}
//
//struct ContestsView: View {
//    @StateObject private var viewModel = ContestsViewModel()
//    @State private var isExpanded = false
//
//    var body: some View {
//        VStack(alignment: .leading, spacing: 15) {
//            Button(action: { isExpanded.toggle() }) {
//                HStack {
//                    Text("Group Investments")
//                        .font(.headline)
//                    Spacer()
//                    Image(systemName: isExpanded ? "chevron.up" : "chevron.down")
//                }
//            }
//            .buttonStyle(PlainButtonStyle())
//
//            if isExpanded {
//                if viewModel.isLoading {
//                    ProgressView()
//                } else if let errorMessage = viewModel.errorMessage {
//                    Text(errorMessage)
//                        .foregroundColor(.red)
//                } else if viewModel.pendingContests.isEmpty && viewModel.activeContests.isEmpty {
//                    Text("No contests available.")
//                        .foregroundColor(.gray)
//                } else {
//                    contestsList
//                }
//            }
//        }
//        .padding()
//        .background(Color.gray.opacity(0.1))
//        .cornerRadius(10)
//        .task {
//            if viewModel.pendingContests.isEmpty && viewModel.activeContests.isEmpty {
//                await viewModel.fetchContests()
//            }
//        }
//        .alert("Notice", isPresented: .constant(viewModel.errorMessage != nil), actions: {
//            Button("OK") {
//                viewModel.errorMessage = nil
//            }
//        }, message: {
//            Text(viewModel.errorMessage ?? "")
//        })
//    }
//
//    private var contestsList: some View {
//        VStack(alignment: .leading, spacing: 15) {
//            if !viewModel.pendingContests.isEmpty {
//                Text("Pending Invitations")
//                    .font(.headline)
//                ForEach(viewModel.pendingContests) { contest in
//                    CollapsibleContestRow(contest: contest) {
//                        Task {
//                            await viewModel.declineContest(contest)
//                        }
//                    }
//                }
//            }
//            
//            if !viewModel.activeContests.isEmpty {
//                Text("Active Contests")
//                    .font(.headline)
//                ForEach(viewModel.activeContests) { contest in
//                    CollapsibleContestRow(contest: contest) {
//                        // No decline action for active contests
//                    }
//                }
//            }
//            
//            NavigationLink(destination: CreateCompetitionView()) {
//                Text("Create New Contest")
//                    .font(.headline)
//                    .foregroundColor(.white)
//                    .frame(maxWidth: .infinity)
//                    .padding()
//                    .background(Color.blue)
//                    .cornerRadius(10)
//            }
//        }
//    }
//}
//
//struct CollapsibleContestRow: View {
//    let contest: Contest
//    @State private var isExpanded = false
//    var declineAction: () -> Void
//
//    var body: some View {
//        VStack(alignment: .leading, spacing: 8) {
//            Button(action: { isExpanded.toggle() }) {
//                HStack {
//                    Text(contest.name)
//                        .font(.headline)
//                    Spacer()
//                    Text("Total Pot: \(formatCurrency(contest.totalPot))")
//                        .font(.subheadline)
//                    Image(systemName: isExpanded ? "chevron.up" : "chevron.down")
//                }
//            }
//            .buttonStyle(PlainButtonStyle())
//
//            if isExpanded {
//                expandedContent
//            }
//        }
//        .padding()
//        .background(RoundedRectangle(cornerRadius: 15)
//            .fill(contest.status == "Pending" ? Color.yellow.opacity(0.1) : Color.green.opacity(0.1))
//            .shadow(color: Color.gray.opacity(0.2), radius: 5, x: 0, y: 2))
//        .overlay(
//            RoundedRectangle(cornerRadius: 15)
//                .stroke(contest.status == "Pending" ? Color.yellow.opacity(0.3) : Color.green.opacity(0.3), lineWidth: 1)
//        )
//    }
//
//    private var expandedContent: some View {
//        VStack(alignment: .leading, spacing: 8) {
//            infoRow(title: "Group Members", value: contest.members.joined(separator: ", "))
//            infoRow(title: "Workout Type", value: contest.workoutType)
//            infoRow(title: "Number of Workouts", value: "\(contest.numberOfWorkouts)")
//            infoRow(title: "Timeframe", value: contest.timeframe)
//            infoRow(title: "Start Date", value: formatDate(contest.startDate))
//            infoRow(title: "End Date", value: formatDate(contest.endDate))
//            infoRow(title: "Your Investment", value: formatCurrency(contest.investmentAmount))
//
//            if contest.status == "Pending" {
//                HStack {
//                    NavigationLink(destination: BankView(pendingContestInvestment: contest)) {
//                        Text("Review & Invest")
//                            .font(.headline)
//                            .foregroundColor(.white)
//                            .frame(maxWidth: .infinity)
//                            .padding()
//                            .background(Color.blue)
//                            .cornerRadius(10)
//                    }
//
//                    Button(action: declineAction) {
//                        Text("Decline")
//                            .font(.headline)
//                            .foregroundColor(.white)
//                            .frame(maxWidth: .infinity)
//                            .padding()
//                            .background(Color.red)
//                            .cornerRadius(10)
//                    }
//                }
//                .padding(.top, 8)
//            }
//        }
//        .font(.subheadline)
//    }
//
//    private func infoRow(title: String, value: String) -> some View {
//        HStack(alignment: .top) {
//            Text(title + ":")
//                .foregroundColor(.secondary)
//                .frame(width: 120, alignment: .leading)
//            Text(value)
//                .foregroundColor(.primary)
//        }
//    }
//
//    private func formatDate(_ date: Date) -> String {
//        let formatter = DateFormatter()
//        formatter.dateStyle = .medium
//        formatter.timeStyle = .none
//        return formatter.string(from: date)
//    }
//
//    private func formatCurrency(_ amount: Double) -> String {
//        let formatter = NumberFormatter()
//        formatter.numberStyle = .currency
//        formatter.currencyCode = "USD"
//        return formatter.string(from: NSNumber(value: amount)) ?? "$0.00"
//    }
//}
//
//// Ensure your Contest struct is updated to match this structure
//struct Contest: Identifiable {
//    let id: String
//    let name: String
//    let workoutType: String
//    let numberOfWorkouts: Int
//    let timeframe: String
//    let investmentAmount: Double
//    let totalPot: Double
//    let totalParticipants: Int
//    let status: String
//    let members: [String]
//    let startDate: Date
//    let endDate: Date
//    
//    init(id: String, data: [String: Any]) {
//        self.id = id
//        self.name = data["contestName"] as? String ?? ""
//        self.workoutType = data["workoutType"] as? String ?? ""
//        self.numberOfWorkouts = data["numberOfWorkouts"] as? Int ?? 0
//        self.timeframe = data["timeframe"] as? String ?? ""
//        self.investmentAmount = data["investmentAmount"] as? Double ?? 0
//        self.totalPot = data["totalPot"] as? Double ?? 0
//        self.totalParticipants = data["totalParticipants"] as? Int ?? 0
//        self.status = data["status"] as? String ?? "Pending"
//        self.members = data["members"] as? [String] ?? []
//        self.startDate = (data["startDate"] as? Timestamp)?.dateValue() ?? Date()
//        self.endDate = (data["endDate"] as? Timestamp)?.dateValue() ?? Date()
//    }
//}
//
//struct ContestRow: View {
//    let contest: Contest
//    let isPending: Bool
//    
//    var body: some View {
//        VStack(alignment: .leading, spacing: 12) {
//            Text(contest.name)
//                .font(.headline)
//                .foregroundColor(.primary)
//            
//            VStack(alignment: .leading, spacing: 8) {
//                infoRow(title: "Group Members", value: contest.members.joined(separator: ", "))
//                infoRow(title: "Workout Type", value: contest.workoutType)
//                infoRow(title: "Number of Workouts", value: "\(contest.numberOfWorkouts)")
//                infoRow(title: "Timeframe", value: contest.timeframe)
//                infoRow(title: "Start Date", value: formatDate(contest.startDate))
//                infoRow(title: "End Date", value: formatDate(contest.endDate))
//                infoRow(title: "Total Pot", value: formatCurrency(contest.totalPot))
//                infoRow(title: "Your Investment", value: formatCurrency(contest.investmentAmount))
//            }
//            .font(.subheadline)
//            
//            if isPending {
//                NavigationLink(destination: BankView(pendingContestInvestment: contest)) {
//                    Text("Review & Invest")
//                        .font(.headline)
//                        .foregroundColor(.white)
//                        .frame(maxWidth: .infinity)
//                        .padding()
//                        .background(Color.blue)
//                        .cornerRadius(10)
//                }
//                .padding(.top, 8)
//            } else {
//                Text("Status: Active")
//                    .foregroundColor(.green)
//                    .font(.headline)
//                    .padding(.top, 8)
//            }
//        }
//        .padding()
//        .background(RoundedRectangle(cornerRadius: 15)
//            .fill(isPending ? Color.yellow.opacity(0.1) : Color.green.opacity(0.1))
//            .shadow(color: Color.gray.opacity(0.2), radius: 5, x: 0, y: 2))
//        .overlay(
//            RoundedRectangle(cornerRadius: 15)
//                .stroke(isPending ? Color.yellow.opacity(0.3) : Color.green.opacity(0.3), lineWidth: 1)
//        )
//    }
//    
//    private func infoRow(title: String, value: String) -> some View {
//        HStack(alignment: .top) {
//            Text(title + ":")
//                .foregroundColor(.secondary)
//                .frame(width: 120, alignment: .leading)
//            Text(value)
//                .foregroundColor(.primary)
//        }
//    }
//    
//    private func formatDate(_ date: Date) -> String {
//        let formatter = DateFormatter()
//        formatter.dateStyle = .medium
//        formatter.timeStyle = .none
//        return formatter.string(from: date)
//    }
//    
//    private func formatCurrency(_ amount: Double) -> String {
//        let formatter = NumberFormatter()
//        formatter.numberStyle = .currency
//        formatter.currencyCode = "USD"
//        return formatter.string(from: NSNumber(value: amount)) ?? "$0.00"
//    }
//}
//
