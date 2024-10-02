//
//  BankViewModel.swift
//  ChatGPT2
//
//  Created by Ryan Whooley on 8/30/24.
//

import SwiftUI
import Firebase
import FirebaseAuth
import FirebaseFunctions
import FirebaseFirestore
import Stripe
import StripePaymentSheet

struct Investment: Identifiable {
    let id: String
    let amount: Double
    let contestId: String?
    let month: String?
    let timestamp: Date?
    let userId: String?
    let status: String
    let workoutCount: Int // Total number of workouts associated with the investment
    let bonusRate: Double // Bonus percentage (0%, 10%, 20%, 25%, etc.)
    let bonusSquares: Int // Number of bonus squares
}

class BankViewModel: ObservableObject {
    @Published var totalBalance: Double = 0
    @Published var investedBalance: Double = 0
    @Published var freeBalance: Double = 0
    @Published var paymentIntentClientSecret: String?
    @Published var paymentSheet: PaymentSheet?
    @Published var isUserSignedIn: Bool = false
    @Published var stripeAccountLink: URL?
    @Published private(set) var stripeAccountId: String?
    @Published private(set) var externalAccountLast4: String?
    @Published var stripeAccountStatus: String = "checking"
    @Published var currentInvestments: [Investment] = []
    @Published var pendingContestInvestments: [Contest] = [] // New state for pending contest investments
    @Published var pendingTeamInvestments: [Team] = [] // New state for pending team investments
    @Published var activeInvestment: Investment?
    @Published var contestNames: [String: String] = [:]
    @Published var activeContestInvestments: [Contest] = [] // For active contests
    @Published var activeTeamInvestments: [Team] = []
    @Published var activePersonalInvestments: [Investment] = []
    
    @StateObject private var viewModel = BankViewModel()

    
    
    
    private var contestCache: [String: Contest] = [:]
      
    
    enum InvestmentType {
        case contest(Contest)
        case team(Team)
    }

    
    var userId: String = Auth.auth().currentUser?.uid ?? ""
    
    private var db = Firestore.firestore()
    private var functions = Functions.functions()
    
    init() {
        checkAuthenticationState()
        fetchInvestments()
        fetchActiveInvestments()
        fetchCurrentInvestments()
        
    }
    
    var maskedExternalAccount: String {
        guard let last4 = externalAccountLast4 else { return "Not connected" }
        return "*\(last4)"
    }
    
    // Fetch active investment data from Firebase
    func fetchInvestments() {
        guard !userId.isEmpty else {
            print("No userId found")
            return
        }

        print("Fetching investments for userId: \(userId)")

        let db = Firestore.firestore()
        let currentMonthYear = getCurrentMonthYear()
        print("Formatted currentMonthYear: \(currentMonthYear)")

        // Fetch investments where the "month" matches the current month
        db.collection("Investments")
            .whereField("userId", isEqualTo: userId)
            .whereField("month", isGreaterThanOrEqualTo: currentMonthYear)
            .getDocuments { [weak self] (querySnapshot, err) in
                if let err = err {
                    print("Error getting documents: \(err)")
                } else {
                    self?.currentInvestments = querySnapshot?.documents.compactMap { document -> Investment? in
                        let data = document.data()

                        // Extract all necessary fields from Firestore document
                        return Investment(
                            id: document.documentID,
                            amount: data["amount"] as? Double ?? 0,
                            contestId: data["contestId"] as? String,
                            month: data["month"] as? String,
                            timestamp: (data["timestamp"] as? Timestamp)?.dateValue(),
                            userId: data["userId"] as? String,
                            status: data["status"] as? String ?? "Active",
                            workoutCount: data["workoutCount"] as? Int ?? 0, // Add this field
                            bonusRate: data["bonusRate"] as? Double ?? 0.0, // Add this field
                            bonusSquares: data["bonusSquares"] as? Int ?? 0 // Add this field
                        )
                    } ?? []

                    // Notify the view to update
                    DispatchQueue.main.async {
                        self?.objectWillChange.send()
                    }

                    // Now fetch contest-based investments
                    // self?.fetchContestInvestments()
                }
            }
    }


    // Fetch Active Investments from Firestore
    func fetchActiveInvestments() {
            fetchActivePersonalInvestments()
            fetchActiveContestInvestments()
        }

    
    var currentMonthYear: String {
        let formatter = DateFormatter()
        formatter.dateFormat = "MMMM yyyy"
        return formatter.string(from: Date())
    }
        
    func getCurrentMonthYear() -> String {
        let dateFormatter = DateFormatter()
        dateFormatter.dateFormat = "MMMM yyyy"
        let result = dateFormatter.string(from: Date())
        print("getCurrentMonthYear returned: \(result)")
        return result
    }

    private func fetchCurrentInvestments() {
        let db = Firestore.firestore()
        
        // Use this to ensure the format is exactly what you expect in Firestore
        let currentMonthYear = getCurrentMonthYear().trimmingCharacters(in: .whitespacesAndNewlines)

        
        
        print("Current month-year: \(currentMonthYear)")
        
        // Check the current authenticated user ID
        let currentUserId = Auth.auth().currentUser?.uid ?? "No user ID"
        print("User ID: \(currentUserId)")
        
        
        // Fetch investments based on userId and month
        print("Fetching investments for month: \(currentMonthYear)")
        
        db.collection("Investments")
//            .whereField("userId", isEqualTo: currentUserId)
//            .whereField("month", isEqualTo: "September 2024")
            .getDocuments { [weak self] querySnapshot, error in
                guard let self = self else { return }
                
                if let error = error {
                    print("Error fetching current investments: \(error)")
                    return
                }
                
                // Log the number of documents retrieved
                let documentCount = querySnapshot?.documents.count ?? 0
                print("Number of documents retrieved: \(documentCount)")
                
                // Process the investment documents
                let investments = querySnapshot?.documents.compactMap { document -> Investment? in
                    let data = document.data()
                    
                    // Log every key-value pair in the document to inspect its structure
                    data.forEach { key, value in
                        print("Field: \(key), Value: \(value)")
                    }
                    
                    // Now, try parsing the investment
                    let investment = Investment(
                        id: document.documentID,
                        amount: data["amount"] as? Double ?? 0,
                        contestId: data["contestId"] as? String,
                        month: data["month"] as? String,
                        timestamp: (data["timestamp"] as? Timestamp)?.dateValue(),
                        userId: data["userId"] as? String,
                        status: data["status"] as? String ?? "Unknown",
                        workoutCount: data["workoutCount"] as? Int ?? 0,  // Add workoutCount parsing
                        bonusRate: data["bonusRate"] as? Double ?? 0,      // Add bonusRate parsing
                        bonusSquares: data["bonusSquares"] as? Int ?? 0    // Add bonusSquares parsing
                    )

                    
                    print("Parsed investment: \(investment)")
                    return investment
                } ?? []

                
                // Log number of investments after parsing
                print("Number of investments after parsing: \(investments.count)")
                
                // Update the UI with the fetched investments
                DispatchQueue.main.async {
                    self.currentInvestments = investments
                    print("Updated currentInvestments. New count: \(self.currentInvestments.count)")
                    self.objectWillChange.send()
                }
            }
    }

    private func fetchActivePersonalInvestments() {
        let db = Firestore.firestore()
        let currentMonthYear = getCurrentMonthYear()

        print("Fetching active personal investments for month: \(currentMonthYear)")
        print("Current user ID: \(Auth.auth().currentUser?.uid ?? "No user ID")")

        db.collection("Investments")
            .whereField("userId", isEqualTo: Auth.auth().currentUser?.uid ?? "")
         
            .whereField("month", isEqualTo: currentMonthYear)  // Optionally filter by month
            .getDocuments { [weak self] querySnapshot, error in
                guard let self = self else {
                    print("Self is nil, exiting early")
                    return
                }
                
                if let error = error {
                    print("Error fetching personal investments: \(error)")
                    return
                }
                
                guard let querySnapshot = querySnapshot else {
                    print("QuerySnapshot is nil")
                    return
                }
                
                let investments = querySnapshot.documents.compactMap { document -> Investment? in
                    let data = document.data()
                    print("Processing document ID: \(document.documentID)")
                    print("Raw document data: \(data)")

                    guard let amount = data["amount"] as? Double else {
                        print("Failed to parse amount for document \(document.documentID)")
                        return nil
                    }

                    let investment = Investment(
                        id: document.documentID,
                        amount: data["amount"] as? Double ?? 0,
                        contestId: data["contestId"] as? String,
                        month: data["month"] as? String,
                        timestamp: (data["timestamp"] as? Timestamp)?.dateValue(),
                        userId: data["userId"] as? String,
                        status: data["status"] as? String ?? "Unknown",
                        workoutCount: data["workoutCount"] as? Int ?? 0,  // Add workoutCount parsing
                        bonusRate: data["bonusRate"] as? Double ?? 0,      // Add bonusRate parsing
                        bonusSquares: data["bonusSquares"] as? Int ?? 0    // Add bonusSquares parsing
                    )


                    print("Successfully parsed investment: \(investment)")
                    return investment
                }

                print("Number of investments after parsing: \(investments.count)")

                DispatchQueue.main.async {
                    self.activePersonalInvestments = investments
                    print("Updated activePersonalInvestments. New count: \(self.activePersonalInvestments.count)")
                    self.objectWillChange.send()
                }
            }
    }


        private func fetchActiveContestInvestments() {
            let db = Firestore.firestore()
            let currentDate = Date()
            
            db.collection("contests")
                .whereField("members", arrayContains: Auth.auth().currentUser?.email ?? "")
                .whereField("status", isEqualTo: "Active")
                .getDocuments { [weak self] querySnapshot, error in
                    guard let self = self else { return }
                    
                    
                    if let error = error {
                        print("Error fetching contest investments: \(error)")
                        return
                    }
                    
                    let contests = querySnapshot?.documents.compactMap { document -> Contest? in
                        let data = document.data()
                        let contest = Contest(id: document.documentID, data: data)
                        if currentDate >= contest.startDate && currentDate <= contest.endDate {
                            return contest
                        }
                        return nil
                    } ?? []
                    
                    DispatchQueue.main.async {
                        self.activeContestInvestments = contests
                        self.objectWillChange.send()
                    }
                }
        }

    
    
    // Fetch investments with contestId and check contest status and date range
    private func fetchContestInvestments(contestsToFetch: [String: Investment], currentDate: Date) {
        let db = Firestore.firestore()
        let group = DispatchGroup()
        var activeContestInvestments: [Contest] = []

        for (contestId, _) in contestsToFetch {
            group.enter()
            db.collection("contests").document(contestId).getDocument { documentSnapshot, error in
                defer { group.leave() }
                
                if let error = error {
                    print("Error fetching contest \(contestId): \(error)")
                    return
                }
                
                guard let data = documentSnapshot?.data() else {
                    print("No data found for contest \(contestId)")
                    return
                }
                
                let contest = Contest(id: contestId, data: data)
                print("Fetched contest: \(contest.contestName), Status: \(contest.status)")
                
                let isUserMember = contest.members.contains(where: { $0.lowercased() == self.userId.lowercased() })
                let isDateInRange = currentDate >= contest.startDate && currentDate <= contest.endDate
                let isStatusValid = contest.status == "Active" || contest.status == "Pending"
                
                if isUserMember && isDateInRange && isStatusValid {
                    print("Adding contest to active investments: \(contest.contestName)")
                    activeContestInvestments.append(contest)
                } else {
                    print("Contest not added. User member: \(isUserMember), Date in range: \(isDateInRange), Status valid: \(isStatusValid)")
                }
            }
        }

        group.notify(queue: .main) {
            print("All contests fetched. Active contests count: \(activeContestInvestments.count)")
            self.activeContestInvestments = activeContestInvestments
            print("Updated activeContestInvestments, count: \(self.activeContestInvestments.count)")
            self.objectWillChange.send()
        }
    }
    
    // Helper function to fetch contest details
    // Helper function to fetch contest details
    func fetchContest(contestId: String, completion: @escaping (Contest?) -> Void) {
        if let cachedContest = contestCache[contestId] {
            completion(cachedContest)
            return
        }
        
        let db = Firestore.firestore()
        let contestRef = db.collection("contests").document(contestId)
        
        // Fetch the contest document using getDocument
        contestRef.getDocument { documentSnapshot, error in
            if let error = error {
                print("Error fetching contest: \(error)")
                completion(nil)
                return
            }
            
            // Ensure the document data exists
            guard let data = documentSnapshot?.data(),
                          let status = data["status"] as? String,
                          let startDateTimestamp = data["startDate"] as? Timestamp,
                          let endDateTimestamp = data["endDate"] as? Timestamp else {
                        completion(nil)
                        return
                    }

            // Initialize the Contest object using your custom initializer
            let contest = Contest(id: contestId, data: data)
            completion(contest)

            // Cache the contest
                    self.contestCache[contestId] = contest
                    completion(contest)
            
        }
    }

    
    
        // Fetch contest names for investments with contestIds
        private func fetchContestNamesIfNeeded() {
            let contestIds = currentInvestments.compactMap { $0.contestId }

            for contestId in contestIds {
                if contestNames[contestId] == nil {
                    // Fetch contest name if not already cached
                    fetchContestName(for: contestId)
                }
            }
        }

        // Fetch contest name for a specific contestId
        private func fetchContestName(for contestId: String) {
            let contestRef = db.collection("contests").document(contestId)
            contestRef.getDocument { [weak self] document, error in
                guard let self = self else { return }

                if let error = error {
                    print("Error fetching contest name: \(error)")
                    self.contestNames[contestId] = "Unknown Contest"
                    return
                }

                if let contestData = document?.data(),
                   let contestName = contestData["name"] as? String {
                    DispatchQueue.main.async {
                        self.contestNames[contestId] = contestName
                    }
                } else {
                    DispatchQueue.main.async {
                        self.contestNames[contestId] = "Unknown Contest"
                    }
                }
            }
        }

        // Safely fetch the contest name
    // Fetch contest name
       func getContestName(for contestId: String) -> String {
           return contestNames[contestId] ?? "Fetching..."
       }

       func getContest(for id: String) async throws -> Contest {
           if let cachedContest = contestCache[id] {
               return cachedContest
           }
           
           let contestRef = db.collection("contests").document(id)
           let document = try await contestRef.getDocument()
           
           guard let contestData = document.data() else {
               throw NSError(domain: "ContestError", code: 0, userInfo: [NSLocalizedDescriptionKey: "Contest document does not exist or is empty"])
           }
           
           let fetchedContest = Contest(id: document.documentID, data: contestData)
           contestCache[id] = fetchedContest
           return fetchedContest
       }
   
    
    func fetchCurrentMonthInvestment(completion: @escaping (Investment?) -> Void) {
        let dateFormatter = DateFormatter()
        dateFormatter.dateFormat = "MMMM yyyy"
        let currentMonthYear = getCurrentMonthYear()
        print("Formatted currentMonthYear: \(currentMonthYear)")


        db.collection("Investments")
            .whereField("userId", isEqualTo: Auth.auth().currentUser?.uid ?? "")
            .whereField("month", isEqualTo: currentMonthYear)
            .getDocuments { (querySnapshot, error) in
                if let error = error {
                    print("Error fetching investment: \(error.localizedDescription)")
                    completion(nil)
                    return
                }

                guard let documents = querySnapshot?.documents, !documents.isEmpty else {
                    completion(nil)
                    return
                }

                if let document = documents.first {
                    let investmentData = document.data()

                    if let amount = investmentData["amount"] as? Double {
                        let contestId = investmentData["contestId"] as? String
                        
                        let investment = Investment(
                            id: document.documentID,
                            amount: amount,
                            contestId: contestId,
                            month: currentMonthYear,
                            timestamp: (investmentData["timestamp"] as? Timestamp)?.dateValue(),
                            userId: Auth.auth().currentUser?.uid,
                            status: investmentData["status"] as? String ?? "Active",
                            workoutCount: investmentData["workoutCount"] as? Int ?? 0,  // Add workoutCount parsing
                            bonusRate: investmentData["bonusRate"] as? Double ?? 0,      // Add bonusRate parsing
                            bonusSquares: investmentData["bonusSquares"] as? Int ?? 0    // Add bonusSquares parsing
                        )

                        self.activeInvestment = investment
                        completion(investment)
                    } else {
                        completion(nil)
                    }
                } else {
                    completion(nil)
                }

            }
    }

    @MainActor
    func fetchPendingInvestments() async {
        guard let userEmail = Auth.auth().currentUser?.email else {
            print("User not logged in")
            return
        }

        do {
            let db = Firestore.firestore()

            // Fetch pending contests
            let contestSnapshot = try await db.collection("contests")
                .whereField("members", arrayContains: userEmail)
                .whereField("status", isEqualTo: "Pending")
                .getDocuments()

            pendingContestInvestments = contestSnapshot.documents.compactMap {
                Contest(id: $0.documentID, data: $0.data())
            }

            // Fetch pending teams (assuming they are stored in a similar structure)
            let teamSnapshot = try await db.collection("teams")
                .whereField("members", arrayContains: userEmail)
                .whereField("status", isEqualTo: "Pending")
                .getDocuments()

            pendingTeamInvestments = teamSnapshot.documents.compactMap {
                Team(id: $0.documentID, data: $0.data())
            }

        } catch {
            print("Error fetching investments: \(error.localizedDescription)")
        }
    }

    
    
    
    func createPaymentIntent(amount: Double, completion: @escaping (String?, Error?) -> Void) {
        functions.httpsCallable("createPaymentIntent").call(["amount": amount]) { result, error in
            if let error = error {
                print("Error creating PaymentIntent: \(error.localizedDescription)")
                completion(nil, error)
                return
            }

            if let data = result?.data as? [String: Any],
               let clientSecret = data["clientSecret"] as? String {
                print("Received client secret: \(clientSecret)")
                completion(clientSecret, nil)
            } else {
                print("Error: Invalid response format")
                completion(nil, NSError(domain: "", code: -1, userInfo: [NSLocalizedDescriptionKey: "Invalid response format"]))
            }
        }
    }

    func recordInvestment(month: String, amount: Double, completion: @escaping (Bool) -> Void) {
        guard let userId = Auth.auth().currentUser?.uid else {
            print("Error: No user ID available")
            DispatchQueue.main.async {
                completion(false)
            }
            return
        }

        let investmentData: [String: Any] = [
            "userId": userId,
            "month": month, // Save the selected month here
            "amount": amount,
            "timestamp": Timestamp(date: Date())
        ]
        
        db.collection("Investments").addDocument(data: investmentData) { [weak self] error in
            guard let self = self else { return }
            
            if let error = error {
                print("Error recording investment: \(error.localizedDescription)")
                DispatchQueue.main.async {
                    completion(false)
                }
            } else {
                print("Investment recorded successfully in Firestore.")
                
                // Update user's balances
                self.updateBalancesAfterInvestment(amount: amount) { updateSuccess in
                    DispatchQueue.main.async {
                        completion(updateSuccess)
                    }
                }
            }
        }
    }

    // Add decline function
       func declinePendingInvestment(investment: InvestmentType, completion: @escaping (Bool) -> Void) {
           switch investment {
           case .contest(let contest):
               // Handle contest decline logic
               declineContestInvestment(contest: contest, completion: completion)
           case .team(let team):
               // Handle team decline logic
               declineTeamInvestment(team: team, completion: completion)
           }
       }

       private func declineContestInvestment(contest: Contest, completion: @escaping (Bool) -> Void) {
           let db = Firestore.firestore()
           let contestRef = db.collection("contests").document(contest.id)

           contestRef.updateData(["investmentStatus": "Declined"]) { error in
               if let error = error {
                   print("Error declining contest: \(error)")
                   completion(false)
               } else {
                   completion(true)
               }
           }
       }

       private func declineTeamInvestment(team: Team, completion: @escaping (Bool) -> Void) {
           let db = Firestore.firestore()
           let teamRef = db.collection("teams").document(team.id)

           teamRef.updateData(["investmentStatus": "Declined"]) { error in
               if let error = error {
                   print("Error declining team: \(error)")
                   completion(false)
               } else {
                   completion(true)
               }
           }
       }
    
    private func updateBalancesAfterInvestment(amount: Double, completion: @escaping (Bool) -> Void) {
        let userRef = db.collection("users").document(userId)
        
        db.runTransaction({ (transaction, errorPointer) -> Any? in
            let userDocument: DocumentSnapshot
            do {
                try userDocument = transaction.getDocument(userRef)
            } catch let fetchError as NSError {
                errorPointer?.pointee = fetchError
                return nil
            }
            
            guard let oldInvestedBalance = userDocument.data()?["investedBalance"] as? Double,
                  let oldFreeBalance = userDocument.data()?["freeBalance"] as? Double else {
                let error = NSError(domain: "AppErrorDomain", code: -1, userInfo: [NSLocalizedDescriptionKey: "Unable to retrieve user balances"])
                errorPointer?.pointee = error
                return nil
            }
            
            let newInvestedBalance = oldInvestedBalance + amount
            let newFreeBalance = oldFreeBalance - amount
            
            transaction.updateData([
                "investedBalance": newInvestedBalance,
                "freeBalance": newFreeBalance
            ], forDocument: userRef)
            
            return nil
        }) { (object, error) in
            if let error = error {
                print("Transaction failed: \(error)")
                completion(false)
            } else {
                print("Balances updated successfully after investment.")
                DispatchQueue.main.async {
                    self.investedBalance += amount
                    self.freeBalance -= amount
                }
                completion(true)
            }
        }
    }


    func getCurrentYear() -> String {
        let formatter = DateFormatter()
        formatter.dateFormat = "yyyy"
        return formatter.string(from: Date())
    }

    func updateInvestedBalance(amount: Double) {
        let userRef = db.collection("users").document(userId)
        
        db.runTransaction({ (transaction, errorPointer) -> Any? in
            let userDocument: DocumentSnapshot
            do {
                try userDocument = transaction.getDocument(userRef)
            } catch let fetchError as NSError {
                errorPointer?.pointee = fetchError
                return nil
            }
            
            guard let oldInvestedBalance = userDocument.data()?["investedBalance"] as? Double else {
                let error = NSError(domain: "AppErrorDomain", code: -1, userInfo: [NSLocalizedDescriptionKey: "Unable to retrieve invested balance"])
                errorPointer?.pointee = error
                return nil
            }
            
            let newInvestedBalance = oldInvestedBalance + amount
            
            // Update the Firestore document
            transaction.updateData([
                "investedBalance": newInvestedBalance,
                "freeBalance": FieldValue.increment(-amount)
            ], forDocument: userRef)
            
            return nil
        }) { (object, error) in
            if let error = error {
                print("Transaction failed: \(error)")
            } else {
                print("Invested balance successfully updated!")
                
                // Update the local state
                DispatchQueue.main.async {
                    self.investedBalance += amount
                    self.freeBalance -= amount
                }
            }
        }
    }



    private func updateBalancesAfterInvestment(investmentAmount: Double, completion: @escaping (Bool) -> Void) {
        UserBalanceManager.shared.updateBalancesAfterInvestment(userId: userId, investmentAmount: investmentAmount) { error in
            if let error = error {
                print("Error updating balances after investment: \(error.localizedDescription)")
                completion(false)
            } else {
                print("Balances updated successfully after investment.")
                self.fetchBalances { _, _, _, _ in
                    completion(true)
                }
            }
        }
    }
    
    // Fetch user balances
    func fetchBalances(completion: ((Double, Double, Double, Error?) -> Void)? = nil) {
            UserBalanceManager.shared.getUserBalances(userId: userId) { [weak self] total, invested, free, error in
                DispatchQueue.main.async {
                    self?.totalBalance = total
                    self?.investedBalance = invested
                    self?.freeBalance = free
                    completion?(total, invested, free, error)
                }
            }
        }
    
    // Fetch external account information from Stripe
    func fetchExternalAccountInfo() {
        functions.httpsCallable("getStripeExternalAccountInfo").call() { [weak self] result, error in
            if let error = error as NSError? {
                print("Error fetching external account info: \(error.localizedDescription)")
                return
            }
            
            if let data = result?.data as? [String: Any],
               let last4 = data["last4"] as? String {
                DispatchQueue.main.async {
                    self?.externalAccountLast4 = last4
                }
            } else {
                print("No external account found or invalid response format")
                DispatchQueue.main.async {
                    self?.externalAccountLast4 = nil
                }
            }
        }
    }
    
    // Check authentication state
    // Check authentication state
    func checkAuthenticationState() {
        if let user = Auth.auth().currentUser {
            print("User is signed in.")
            print("User ID: \(user.uid)")
            print("User Email: \(user.email ?? "No email")")
            isUserSignedIn = true
        } else {
            print("No user is signed in.")
            isUserSignedIn = false
        }
    }
    
    // Sign in anonymously
    func signInAnonymously(completion: @escaping (Bool, String?) -> Void) {
        Auth.auth().signInAnonymously { authResult, error in
            if let error = error {
                print("Error signing in anonymously: \(error.localizedDescription)")
                completion(false, error.localizedDescription)
            } else if let user = authResult?.user {
                print("User signed in anonymously with ID: \(user.uid)")
                self.isUserSignedIn = true
                completion(true, nil)
            } else {
                print("Unknown error occurred during anonymous sign-in")
                completion(false, "Unknown error occurred")
            }
        }
    }
    
    // Create a connected Stripe account
    func createConnectedAccount(completion: @escaping (Result<String, Error>) -> Void) {
        functions.httpsCallable("createStripeConnectedAccount").call { (result, error) in
            if let error = error {
                completion(.failure(error))
            } else if let data = result?.data as? [String: Any], let accountId = data["accountId"] as? String {
                completion(.success(accountId))
            } else {
                completion(.failure(NSError(domain: "", code: -1, userInfo: [NSLocalizedDescriptionKey: "Failed to create account"])))
            }
        }
    }
    
    // Onboard the connected Stripe account
    func onboardConnectedAccount(accountId: String, completion: @escaping (Result<String, Error>) -> Void) {
        functions.httpsCallable("createStripeAccountLink").call(["accountId": accountId]) { (result, error) in
            if let error = error {
                completion(.failure(error))
            } else if let data = result?.data as? [String: Any], let url = data["url"] as? String {
                completion(.success(url))
            } else {
                completion(.failure(NSError(domain: "", code: -1, userInfo: [NSLocalizedDescriptionKey: "Failed to create account link"])))
            }
        }
    }
    
    // Create or retrieve a Stripe account
    func createOrRetrieveStripeAccount(completion: @escaping (Result<URL, Error>) -> Void) {
        let functionName = stripeAccountStatus == "not_created" ? "createStripeConnectedAccount" : "checkStripeAccountStatus"
        
        functions.httpsCallable(functionName).call() { result, error in
            if let error = error {
                completion(.failure(error))
                return
            }
            
            if let data = result?.data as? [String: Any],
               let urlString = data["onboardingUrl"] as? String,
               let url = URL(string: urlString) {
                completion(.success(url))
            } else {
                completion(.failure(NSError(domain: "", code: -1, userInfo: [NSLocalizedDescriptionKey: "Invalid response format"])))
            }
        }
    }
    
    func initializePaymentSheet(amount: Double, completion: @escaping (Bool, String?) -> Void) {
            createPaymentIntent(amount: amount) { clientSecret, error in
                if let error = error {
                    completion(false, error.localizedDescription)
                    return
                }

                if let clientSecret = clientSecret {
                    DispatchQueue.main.async {
                        var configuration = PaymentSheet.Configuration()
                        configuration.merchantDisplayName = "Your App Name"
                        
                        self.paymentSheet = PaymentSheet(paymentIntentClientSecret: clientSecret, configuration: configuration)
                        
                        print("PaymentSheet initialized successfully.")
                        completion(true, nil)
                    }
                } else {
                    completion(false, "Failed to create payment sheet")
                }
            }
        }
    
    // Initiate a Stripe payment
    func initiateStripePayment(amount: Double, completion: @escaping (Bool, String?) -> Void) {
        createPaymentIntent(amount: amount) { clientSecret, error in
            if let error = error {
                completion(false, error.localizedDescription)
                return
            }

            if let clientSecret = clientSecret {
                var configuration = PaymentSheet.Configuration()
                configuration.merchantDisplayName = "Your App Name"
                
                // Initialize the PaymentSheet
                self.paymentSheet = PaymentSheet(paymentIntentClientSecret: clientSecret, configuration: configuration)
                
                print("PaymentSheet initialized successfully.")
                completion(true, nil)
            } else {
                completion(false, "Failed to create payment sheet")
            }
        }
    }


    
    // Confirm payment with server
    func confirmPayment(amount: Double, completion: @escaping (Result<Void, Error>) -> Void) {
        functions.httpsCallable("confirmPayment").call(["amount": amount]) { result, error in
            if let error = error {
                print("LOG: Error confirming payment: \(error.localizedDescription)")
                completion(.failure(error))
            } else if let data = result?.data as? [String: Any],
                      let isConfirmed = data["confirmed"] as? Bool, isConfirmed {
                print("LOG: Payment confirmation successful")
                completion(.success(()))
            } else {
                print("LOG: Unexpected response from server during payment confirmation")
                completion(.failure(NSError(domain: "PaymentConfirmation", code: 0, userInfo: [NSLocalizedDescriptionKey: "Failed to confirm payment"])))
            }
        }
    }


        func updateBalance(amount: Double, completion: @escaping (Result<Void, Error>) -> Void) {
            let userRef = db.collection("users").document(userId)
            userRef.getDocument { (document, error) in
                if let error = error {
                    print("LOG: Error fetching user document: \(error.localizedDescription)")
                    completion(.failure(error))
                    return
                }
                
                guard let document = document, document.exists else {
                    print("LOG: User document does not exist")
                    completion(.failure(NSError(domain: "UserDocument", code: 0, userInfo: [NSLocalizedDescriptionKey: "User document not found"])))
                    return
                }
                
                let currentTotalBalance = document.data()?["totalBalance"] as? Double ?? 0
                let currentInvestedBalance = document.data()?["investedBalance"] as? Double ?? 0
                let currentFreeBalance = document.data()?["freeBalance"] as? Double ?? 0
                
                let newTotalBalance = currentTotalBalance + amount
                let newFreeBalance = currentFreeBalance + amount
                
                userRef.updateData([
                    "totalBalance": newTotalBalance,
                    "investedBalance": currentInvestedBalance,
                    "freeBalance": newFreeBalance
                ]) { error in
                    if let error = error {
                        print("LOG: Error updating balance: \(error.localizedDescription)")
                        completion(.failure(error))
                    } else {
                        print("LOG: Balance updated successfully")
                        DispatchQueue.main.async {
                            self.totalBalance = newTotalBalance
                            self.investedBalance = currentInvestedBalance
                            self.freeBalance = newFreeBalance
                        }
                        completion(.success(()))
                    }
                }
            }
        }

    
    // Update user balances in Firestore
    private func updateUserBalances(userId: String, totalBalance: Double, investedBalance: Double, freeBalance: Double, completion: @escaping (Error?) -> Void) {
            let userRef = db.collection("users").document(userId)
            
            userRef.updateData([
                "totalBalance": totalBalance,
                "investedBalance": investedBalance,
                "freeBalance": freeBalance
            ]) { error in
                if let error = error {
                    print("LOG: Error updating balances in Firestore: \(error.localizedDescription)")
                } else {
                    print("LOG: Balances updated successfully in Firestore")
                    DispatchQueue.main.async {
                        self.totalBalance = totalBalance
                        self.investedBalance = investedBalance
                        self.freeBalance = freeBalance
                    }
                }
                completion(error)
            }
        }
    
    // Check and create Stripe account if necessary
    func checkAndCreateStripeAccount(completion: @escaping (Result<CheckStripeAccountResponse, Error>) -> Void) {
        print("Calling checkAndCreateStripeAccount")
        functions.httpsCallable("checkAndCreateStripeAccount").call() { result, error in
            if let error = error {
                print("Error in checkAndCreateStripeAccount: \(error.localizedDescription)")
                completion(.failure(error))
            } else if let data = result?.data as? [String: Any],
                      let status = data["status"] as? String,
                      let accountId = data["accountId"] as? String {
                print("Received data: \(data)")
                let accountLink = data["accountLink"] as? String
                let response = CheckStripeAccountResponse(status: status, accountId: accountId, accountLink: accountLink)
                completion(.success(response))
            } else {
                print("Invalid response format")
                completion(.failure(NSError(domain: "", code: -1, userInfo: [NSLocalizedDescriptionKey: "Invalid response format"])))
            }
        }
    }
    
    // Check Stripe account status
    func checkAccountStatus(completion: @escaping (Result<Void, Error>) -> Void) {
        functions.httpsCallable("checkStripeAccountStatus").call() { [weak self] result, error in
            if let error = error {
                completion(.failure(error))
                return
            }
            
            if let data = result?.data as? [String: Any],
               let status = data["status"] as? String {
                DispatchQueue.main.async {
                    self?.stripeAccountStatus = status
                }
                completion(.success(()))
            } else {
                completion(.failure(NSError(domain: "", code: -1, userInfo: [NSLocalizedDescriptionKey: "Invalid response format"])))
            }
        }
    }
    
    // Initiate a Stripe withdrawal
    func initiateStripeWithdrawal(amount: Int, completion: @escaping (Result<String, Error>) -> Void) {
        functions.httpsCallable("initiateStripeWithdrawal").call(["amount": amount]) { result, error in
            if let error = error as NSError? {
                print("Error initiating withdrawal: \(error.localizedDescription)")
                completion(.failure(error))
                return
            }
            
            guard let data = result?.data as? [String: Any],
                  let success = data["success"] as? Bool,
                  let transferId = data["transferId"] as? String else {
                print("Invalid response format")
                completion(.failure(NSError(domain: "InvalidResponse", code: 0, userInfo: [NSLocalizedDescriptionKey: "Invalid response from server"])))
                return
            }
            
            if success {
                completion(.success(transferId))
            } else {
                completion(.failure(NSError(domain: "WithdrawalFailed", code: 0, userInfo: [NSLocalizedDescriptionKey: "Withdrawal failed"])))
            }
        }
    }
    
//    func getContestName(for contestId: String) -> String {
//        if let cachedName = contestNames[contestId] {
//            return cachedName
//        } else {
//            // Temporarily set a placeholder value in contestNames to trigger a re-render
//            contestNames[contestId] = "Loading..."
//            
//            // Fetch contest name from Firestore asynchronously
//            let contestRef = Firestore.firestore().collection("contests").document(contestId)
//            contestRef.getDocument { document, error in
//                if let error = error {
//                    print("Error fetching contest name: \(error)")
//                    self.contestNames[contestId] = "Unknown Contest"
//                    return
//                }
//                
//                if let contestData = document?.data(),
//                   let contestName = contestData["name"] as? String {
//                    DispatchQueue.main.async {
//                        self.contestNames[contestId] = contestName
//                    }
//                } else {
//                    DispatchQueue.main.async {
//                        self.contestNames[contestId] = "Unknown Contest"
//                    }
//                }
//            }
//            
//            return contestNames[contestId] ?? "Unknown Contest" // Return placeholder or final result
//        }
//    }

}



struct CheckStripeAccountResponse {
    let status: String
    let accountId: String
    let accountLink: String?
}

struct WithdrawalResponse {
    let success: Bool
    let transferId: String?
    let errorMessage: String?
}
