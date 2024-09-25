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
    let month: String?
    let year: String?
    let amount: Double
    let contestId: String?
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
    }
    
    var maskedExternalAccount: String {
        guard let last4 = externalAccountLast4 else { return "Not connected" }
        return "*\(last4)"
    }
    
    // Fetch investment data from Firebase
    func fetchInvestments() {
            guard let userId = Auth.auth().currentUser?.uid else { return }

            let investmentsRef = db.collection("Investments").whereField("userId", isEqualTo: userId)

            investmentsRef.getDocuments { [weak self] (querySnapshot, error) in
                guard let self = self else { return }

                if let error = error {
                    print("Error fetching investments: \(error.localizedDescription)")
                    return
                }

                guard let documents = querySnapshot?.documents else {
                    print("No documents found")
                    return
                }

                let fetchedInvestments = documents.compactMap { document -> Investment? in
                    let data = document.data()
                    guard let amount = data["amount"] as? Double else { return nil }
                    let month = data["month"] as? String
                    let contestId = data["contestId"] as? String
                    return Investment(id: document.documentID, month: month, year: "", amount: amount, contestId: contestId)
                }

                DispatchQueue.main.async {
                    self.currentInvestments = fetchedInvestments
                    self.fetchContestNamesIfNeeded()
                }
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
        func getContestName(for contestId: String) -> String {
            return contestNames[contestId] ?? "Fetching..."
        }
    
    
    func fetchCurrentMonthInvestment(completion: @escaping (Investment?) -> Void) {
        let dateFormatter = DateFormatter()
        dateFormatter.dateFormat = "MMMM yyyy"
        let currentMonthYear = dateFormatter.string(from: Date())

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
                            id: document.documentID, // Use the document ID as the unique ID
                            month: currentMonthYear,
                            year: String(currentMonthYear.suffix(4)),
                            amount: amount,
                            contestId: contestId // This will handle both nil and valid contestIds
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
    func fetchBalances(completion: @escaping (Double, Double, Double, Error?) -> Void) {
        UserBalanceManager.shared.getUserBalances(userId: self.userId) { total, invested, free, error in
            if let error = error {
                print("Error fetching balances: \(error)")
            } else {
                DispatchQueue.main.async {
                    self.totalBalance = total
                    self.investedBalance = invested
                    self.freeBalance = free
                }
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
