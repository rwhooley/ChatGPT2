//
//  HomeContestsView.swift
//  ChatGPT2
//
//  Created by Ryan Whooley on 9/17/24.
//

import SwiftUI
import FirebaseFirestore
import FirebaseAuth

class HomeContestsViewModel: ObservableObject {
    @Published var pendingContests: [Contest] = []
    @Published var activeContests: [Contest] = []
    @Published var isLoading = false
    @Published var errorMessage: String?
    
    var contests: [Contest] = []

    
    @MainActor
    func fetchContests() async {
        guard let userEmail = Auth.auth().currentUser?.email else {
            errorMessage = "User not logged in"
            return
        }
        
        isLoading = true
        defer { isLoading = false }
        
        do {
            let db = Firestore.firestore()
            let snapshot = try await db.collection("contests")
                .whereField("members", arrayContains: userEmail)
                .getDocuments()
            
            // Initialize contests array
            var contests: [Contest] = []
            
            // Iterate through documents and try to create Contest objects
            for document in snapshot.documents {
                let contest = Contest(id: document.documentID, data: document.data()) // No need for optional binding
                contests.append(contest)
            }

            
            let now = Date()
            
            // Filter active and pending contests
            activeContests = contests.filter { contest in
                contest.status == "Active" &&
                contest.startDate <= now &&
                contest.endDate >= now
            }

            pendingContests = contests.filter { contest in
                contest.status == "Pending" ||
                (contest.status == "Active" && contest.startDate > now)
            }

            
        } catch {
            errorMessage = "Error fetching contests: \(error.localizedDescription)"
        }
    }

    
    @MainActor
    func declineContest(_ contest: Contest) async {
        // Implement decline contest logic here
        pendingContests.removeAll { $0.id == contest.id }
    }
}

struct HomeContestsView: View {
    @StateObject private var viewModel = HomeContestsViewModel()
    @State private var showingCreateCompetition = false
    
    var body: some View {
                VStack {
                    if viewModel.isLoading {
                        loadingView
                    } else if let errorMessage = viewModel.errorMessage {
                        errorView(errorMessage)
                    } else {
                        activeContestsSection
                        
                        if !viewModel.pendingContests.isEmpty {
                            pendingContestsSection
                        }
                    }
                    
                    createContestButton
                        .padding()
                }
//                .padding(.bottom)
            
            .background(Color.gray.opacity(0.05).edgesIgnoringSafeArea(.all))
            .navigationTitle("Contests")
            .task {
                await viewModel.fetchContests()
            }
            .sheet(isPresented: $showingCreateCompetition) {
                CreateCompetitionView()
            }
            .alert("Notice", isPresented: .constant(viewModel.errorMessage != nil), actions: {
                Button("OK") { viewModel.errorMessage = nil }
            }, message: {
                Text(viewModel.errorMessage ?? "")
            })
        }
        
        private var loadingView: some View {
            VStack {
                ProgressView()
                Text("Loading contests...")
                    .foregroundColor(.secondary)
            }
            .frame(maxWidth: .infinity, maxHeight: .infinity)
        }
        
        private func errorView(_ message: String) -> some View {
            Text(message)
                .foregroundColor(.red)
                .padding()
                .background(Color.red.opacity(0.1))
                .cornerRadius(10)
        }
        
    private var activeContestsSection: some View {
        VStack(alignment: .leading, spacing: 20) {
            Text("Active Contests")
                .font(.title2)
                .fontWeight(.bold)
            
            if viewModel.activeContests.isEmpty {
                emptyStateView("No active contests. Start one!")
                    .padding(.horizontal, 16)
            } else {
                ForEach(viewModel.activeContests) { contest in
                    activeContestCard(for: contest)
                }
            }
        }
    }

        
    private var pendingContestsSection: some View {
        VStack(alignment: .leading, spacing: 16) {
            sectionHeader("Pending Contests")
            
            ForEach(viewModel.pendingContests) { contest in
                pendingContestCard(for: contest)
            }
        }
    }

        
    private func activeContestCard(for contest: Contest) -> some View {
        VStack(alignment: .leading, spacing: 0) {
            CollapsibleContestRow(contest: contest, contests: $viewModel.activeContests) {
                // No decline action for active contests
            }
            .padding(.horizontal)
            .padding(.vertical, 12)
            .background(Color(UIColor.systemGreen).opacity(0.2))
            
            ContestTrackingModule(viewModel: ContestTrackingViewModel(contest: contest))
                .padding(.horizontal)
                .padding(.vertical, 16)
                .background(Color(UIColor.secondarySystemBackground))
        }
        .background(Color(UIColor.secondarySystemBackground))
        .cornerRadius(12)
    }

    private func pendingContestCard(for contest: Contest) -> some View {
        CollapsibleContestRow(contest: contest, contests: $viewModel.pendingContests) {
            Task { await viewModel.declineContest(contest) }
        }
        .padding()
        .background(Color.yellow.opacity(0.1))
        .cornerRadius(12)
        .shadow(color: Color.black.opacity(0.05), radius: 5, x: 0, y: 2)
    }


        
        
    
        private var createContestButton: some View {
            Button(action: { showingCreateCompetition = true }) {
                HStack {
                    Image(systemName: "plus.circle.fill")
                    Text("Create New Contest")
                }
                .font(.headline)
                .foregroundColor(.white)
                .frame(maxWidth: .infinity)
                .padding()
                .background(Color.gray.opacity(0.1))
                .cornerRadius(12)
            }
            .padding(.horizontal, -16)
        }
        
    
    
        private func sectionHeader(_ title: String) -> some View {
            Text(title)
                .font(.title2)
                .fontWeight(.bold)
        }
        
        private func emptyStateView(_ message: String) -> some View {
            Text(message)
                .foregroundColor(.secondary)
                .frame(maxWidth: .infinity, alignment: .center)
                .padding()
                .background(Color.gray.opacity(0.1))
                .cornerRadius(12)
        }
    
}

struct Contest: Identifiable, Codable {
    let id: String
    let contestName: String
    let createdAt: Date
    let createdBy: String?
    let distance: Double
    let endDate: Date
    let firstPlacePayout: Double?  // Optional
    let investedParticipants: Int
    let investmentAmount: Double
    let members: [String]
    let numberOfWorkouts: Int
    let pace: Double
    let payoutType: String
    let secondPlacePayout: Double?  // Optional
    let startDate: Date
    let status: String
    let thirdPlacePayout: Double?  // Optional
    let totalParticipants: Int
    let totalPot: Double?  // Optional
    let workoutType: String
    var qualifyingWorkouts: [String: Int]?  // Optional
    var timeframe: String

    // CodingKeys if needed, but since you have a custom initializer, they are optional
    enum CodingKeys: String, CodingKey {
        case id
        case contestName
        case createdAt
        case createdBy
        case distance
        case endDate
        case firstPlacePayout
        case investedParticipants
        case investmentAmount
        case members
        case numberOfWorkouts
        case pace
        case payoutType
        case secondPlacePayout
        case startDate
        case status
        case thirdPlacePayout
        case totalParticipants
        case totalPot
        case workoutType
        case qualifyingWorkouts
        case timeframe
    }

    // Implement the custom initializer
    init(id: String, data: [String: Any]) {
        print("Decoding Contest: \(id)")

        self.id = id
        self.contestName = data["contestName"] as? String ?? ""
        print("contestName: \(self.contestName)")
        
        // Timestamp to Date conversion
        self.createdAt = (data["createdAt"] as? Timestamp)?.dateValue() ?? Date()
        self.startDate = (data["startDate"] as? Timestamp)?.dateValue() ?? Date()
        self.endDate = (data["endDate"] as? Timestamp)?.dateValue() ?? Date()
        
        self.createdBy = data["createdBy"] as? String ?? ""
        print("createdBy: \(self.createdBy)")
        
        self.distance = data["distance"] as? Double ?? 0.0
        self.investedParticipants = data["investedParticipants"] as? Int ?? 0
        self.investmentAmount = data["investmentAmount"] as? Double ?? 0.0
        self.members = data["members"] as? [String] ?? []
        print("members: \(self.members)")

        self.numberOfWorkouts = data["numberOfWorkouts"] as? Int ?? 0
        self.pace = data["pace"] as? Double ?? 0.0
        self.payoutType = data["payoutType"] as? String ?? ""
        
        self.firstPlacePayout = data["firstPlacePayout"] as? Double
        self.secondPlacePayout = data["secondPlacePayout"] as? Double
        self.thirdPlacePayout = data["thirdPlacePayout"] as? Double
        
        self.status = data["status"] as? String ?? "Pending"
        self.totalParticipants = data["totalParticipants"] as? Int ?? 0
        self.totalPot = data["totalPot"] as? Double
        
        self.workoutType = data["workoutType"] as? String ?? ""
        self.timeframe = data["timeframe"] as? String ?? ""
        print("timeframe: \(self.timeframe)")
        
        self.qualifyingWorkouts = data["qualifyingWorkouts"] as? [String: Int] ?? [:]
        
        // Add more print statements for debugging as needed
        print("Contest decoded successfully: \(self)")
    }

}
