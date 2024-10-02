//
//  BankView.swift
//  ChatGPT2
//
//  Created by Ryan Whooley on 8/25/24.
//

//
//  BankView.swift
//  ChatGPT2
//
//  Created by Ryan Whooley on 8/25/24.
//

import SwiftUI
import Firebase
import FirebaseAuth
import FirebaseFunctions
import FirebaseFirestore
import Stripe
import StripePaymentSheet
import SafariServices

struct BankView: View {
    @StateObject private var viewModel = BankViewModel()
    @State private var showingAlert = false
    @State private var alertMessage = ""
    @State private var isProcessingPayment: Bool = false
    @State private var paymentConfirmed: Bool = false
    @State private var showingSafari = false
    @State private var safariURL: URL?
    @State private var isCheckingAccount = false
    @State private var stripeAccountStatus: String = "checking"
    @State private var onboardingUrl: String?
    @State private var showingInvestmentMenu = false
    @State private var selectedMonth = ""
    @State private var showInvestmentDetails = false
    @State private var showCreatePersonalInvestment = false
    @State private var showCreateCompetition = false
    @State private var totalBalance: Double = 0
    @State private var investedBalance: Double = 0
    @State private var freeBalance: Double = 0
    @State private var userId: String = Auth.auth().currentUser?.uid ?? ""
    @State private var selectedDepositAmount: Double?
    @State private var balanceListener: ListenerRegistration?
    @State private var pendingContestInvestment: Contest?
    
    @State private var isShowingInvestmentDetail = false
    @State private var selectedInvestment: InvestmentType?
    @State private var selectedTab: TabType = .investments // Enum to handle tab selection
    
    @State private var activeInvestment: Investment?
    
    init(pendingContestInvestment: Contest? = nil) {
        _pendingContestInvestment = State(initialValue: pendingContestInvestment)
    }
    
    enum InvestmentType {
        case contest(Contest)
        case team(Team)
    }
    
    enum TabType: String {
        case investments = "Investments"
        case transactions = "Transactions"
    }
    
    private func setupBalanceListener() {
        balanceListener?.remove() // Remove existing listener to avoid duplicates
        balanceListener = UserBalanceManager.shared.listenForBalanceUpdates(userId: viewModel.userId) { total, invested, free in
            if !self.isProcessingPayment { // Prevent UI updates if payment is in progress
                DispatchQueue.main.async {
                    self.totalBalance = total
                    self.investedBalance = invested
                    self.freeBalance = free
                }
            }
        }
    }

    var body: some View {
            NavigationView {
                ScrollView {
                    VStack(alignment: .leading, spacing: 20) {
                        balanceModule

                        Spacer()
                        
                        segmentedControl

                        if selectedTab == .investments {
                            investmentsSection
                        } else {
                            transactionsSection
                        }
                    }
                    .padding()
                }
                .navigationBarHidden(false)
                .onAppear {
                    viewModel.fetchActiveInvestments()
                    setupBalanceListener()
                    viewModel.fetchBalances { totalBalance, investedBalance, freeBalance, error in
                        if let error = error {
                            print("Error fetching balances: \(error)")
                            return
                        }
                        DispatchQueue.main.async {
                            self.totalBalance = totalBalance
                            self.investedBalance = investedBalance
                            self.freeBalance = freeBalance
                        }
                    }
                    viewModel.fetchExternalAccountInfo()
                    viewModel.checkAccountStatus { _ in }
                    
                    Task {
                        await viewModel.fetchPendingInvestments()
                    }
                }
                .onDisappear {
                    balanceListener?.remove()
                }
                .alert(isPresented: $showingAlert) {
                    Alert(title: Text("Notice"), message: Text(alertMessage), dismissButton: .default(Text("OK")))
                }
                .sheet(isPresented: $showingSafari) {
                    if let url = safariURL {
                        SafariView(url: url)
                    }
                }
                .sheet(isPresented: $showCreatePersonalInvestment) {
                    CreatePersonalInvestmentView()
                }

                .sheet(isPresented: $showCreateCompetition) {
                    CreateCompetitionView()
                }


            }
        }

    // Balance Module Section
    var balanceModule: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text("Wallet")
                .font(.title)
                .fontWeight(.bold)
            Divider()
            
            balanceRow(title: "Total Balance", amount: totalBalance)
            balanceRow(title: "Invested Balance", amount: investedBalance)
            balanceRow(title: "Free Balance", amount: freeBalance)
            
            
            if totalBalance == 0 {
                depositButton
                    .frame(maxWidth: .infinity)
            } else if totalBalance > 0 {
                HStack(spacing: 10) {
                    depositButton
                    withdrawButton
                    investButton
                }
            }

            
        }
        .padding(10)
        .background(RoundedRectangle(cornerRadius: 10).fill(Color.gray.opacity(0.1)))
        
    }


    
    
    // Segmented Control for switching views
    // Segmented Control for switching views with blue selected color
    var segmentedControl: some View {
        Picker("", selection: $selectedTab) {
            Text("Investments").tag(TabType.investments)
            Text("Transactions").tag(TabType.transactions)
        }
        .pickerStyle(SegmentedPickerStyle())
        .background(Color.clear)
        .onAppear {
            UISegmentedControl.appearance().selectedSegmentTintColor = UIColor.systemGray
            UISegmentedControl.appearance().setTitleTextAttributes([.foregroundColor: UIColor.white], for: .selected)
            UISegmentedControl.appearance().setTitleTextAttributes([.foregroundColor: UIColor.gray], for: .normal)
        }
    }


    // Transactions Section (Placeholder)
    var transactionsSection: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text("Transactions")
                .font(.largeTitle)
                .fontWeight(.bold)
            Text("Transaction detail coming soon.")
                .font(.subheadline)
                .foregroundColor(.secondary)
            
            // Placeholder for transaction list
//            Text("No transactions yet.")
//                .foregroundColor(.secondary)
        }
        .padding()
    }

    struct ActiveInvestmentRow: View {
        let name: String
        let amount: Double
        let action: () -> Void
        
        var body: some View {
            HStack {
                VStack(alignment: .leading) {
                    Text(name)
                        .font(.headline)
                    Text(String(format: "$%.2f", amount))
                        .font(.subheadline)
                        .foregroundColor(.secondary)
                }
                Spacer()
                Button(action: action) {
                    Text("View")
                        .foregroundColor(.blue)
                }
            }
            .padding()
            .background(RoundedRectangle(cornerRadius: 10).fill(Color.white))
            .shadow(radius: 2)
        }
    }

    
    var investmentsSection: some View {
        VStack(alignment: .leading, spacing: 8) {
            // Active Investments Subsection
            VStack(alignment: .leading, spacing: 8) {
                    Text("Active Investments")
                        .font(.headline)
                        .fontWeight(.semibold)

                if viewModel.activePersonalInvestments.isEmpty && viewModel.activeContestInvestments.isEmpty {
                           Text("No active investments")
                               .foregroundColor(.secondary)
                       } else {
                           if !viewModel.activePersonalInvestments.isEmpty {
                               Text("Personal Investments")
                                   .font(.subheadline)
                                   .fontWeight(.medium)
                               ForEach(viewModel.activePersonalInvestments) { investment in
                                   CollapsiblePersonalPlanView(personalPlan: PersonalPlan(
                                       id: investment.id,
                                       amount: investment.amount,
                                       month: investment.month ?? "Unknown",
                                       timestamp: investment.timestamp ?? Date(),
                                       userId: investment.userId ?? ""
                                   ))
                                   .padding(.vertical, 4)
                               }
                           }

                        if !viewModel.activeContestInvestments.isEmpty {
                                        Text("Contest Investments")
                                            .font(.subheadline)
                                            .fontWeight(.medium)
                                        ForEach(viewModel.activeContestInvestments) { contest in
                                            CollapsibleContestRow(contest: contest, contests: $viewModel.activeContestInvestments) {
                                    selectedInvestment = .contest(contest)
                                    isShowingInvestmentDetail = true
                                }
                            }
                        }
                    }
                }

//            .padding()
//            .background(RoundedRectangle(cornerRadius: 15).fill(Color.gray.opacity(0.15)))
            .cornerRadius(10)
            .sheet(isPresented: $isShowingInvestmentDetail) {
                if let selectedInvestment = selectedInvestment {
                    switch selectedInvestment {
                    case .contest(let contest):
                        InvestmentDetailView(investment: .contest(contest), onInvest: {
                            // Optional: Any interaction for active contests
                        }, onDecline: {
                            // Optional: Decline or close an active investment (if needed)
                        })
                    case .team(let team):
                        InvestmentDetailView(investment: .team(team), onInvest: {
                            // Optional: Any interaction for active teams
                        }, onDecline: {
                            // Optional: Decline or close an active investment (if needed)
                        })
                    }
                }
            }


            Divider()

            // Pending Investments Subsection
            VStack(alignment: .leading, spacing: 8) {
                Text("Pending Investments")
                    .font(.headline)
                    .fontWeight(.semibold)

                if viewModel.pendingContestInvestments.isEmpty && viewModel.pendingTeamInvestments.isEmpty {
                    Text("No pending investments")
                        .foregroundColor(.secondary)
                } else {
                    if !viewModel.pendingContestInvestments.isEmpty {
                        Text("Contests")
                            .font(.subheadline)
                            .fontWeight(.medium)
                        ForEach(viewModel.pendingContestInvestments, id: \.id) { contest in
                            CollapsibleContestRow(contest: contest, contests: $viewModel.activeContestInvestments) {
                                declinePendingInvestment(.contest(contest))
                            }
                        }
                    }

                    if !viewModel.pendingTeamInvestments.isEmpty {
                        Text("Teams")
                            .font(.subheadline)
                            .fontWeight(.medium)
                        ForEach(viewModel.pendingTeamInvestments, id: \.id) { team in
                            pendingInvestmentRow(name: team.name, amount: team.investmentAmount) {
                                selectedInvestment = .team(team)
                                isShowingInvestmentDetail = true
                            }
                        }
                    }
                }
            }
        }
        .padding()
        .background(RoundedRectangle(cornerRadius: 15).fill(Color.gray.opacity(0.15)))
        .cornerRadius(10)
        .sheet(isPresented: $isShowingInvestmentDetail) {
            if let selectedInvestment = selectedInvestment {
                switch selectedInvestment {
                case .contest(let contest):
                    InvestmentDetailView(investment: .contest(contest), onInvest: {
                        investInPendingInvestment(.contest(contest))
                    }, onDecline: {
                        declinePendingInvestment(.contest(contest))
                    })
                case .team(let team):
                    InvestmentDetailView(investment: .team(team), onInvest: {
                        investInPendingInvestment(.team(team))
                    }, onDecline: {
                        declinePendingInvestment(.team(team))
                    })
                }
            }
        }
    }

    struct ContestInvestmentRow: View {
        let investment: Investment
        @ObservedObject var viewModel: BankViewModel
        @State private var contest: Contest?
        @State private var isLoading = false
        @State private var errorMessage: String?

        var body: some View {
            VStack {
                if isLoading {
                    ProgressView()
                } else if let contest = contest {
                    CollapsibleContestRow(contest: contest, contests: $viewModel.activeContestInvestments) {
                        // No decline action for active investments
                    }
                } else if let errorMessage = errorMessage {
                    Text(errorMessage)
                        .foregroundColor(.red)
                }
            }
            .onAppear {
                loadContest()
            }
        }

        private func loadContest() {
            isLoading = true
            Task {
                do {
                    contest = try await viewModel.getContest(for: investment.contestId!)
                    isLoading = false
                } catch let error as NSError {
                    if error.domain == "ContestError" && error.code == 1 {
                        // Contest is not active
                        errorMessage = "This contest is no longer active"
                    } else {
                        errorMessage = "Failed to load contest: \(error.localizedDescription)"
                    }
                    isLoading = false
                }
            }
        }
    }


    private func activeInvestmentRow(name: String, amount: Double, action: @escaping () -> Void) -> some View {
        Button(action: action) {
            HStack {
                Text(name)
                Spacer()
                Text("$\(amount, specifier: "%.2f")")
            }
            .font(.subheadline)
        }
    }

    private func pendingInvestmentRow(name: String, amount: Double, action: @escaping () -> Void) -> some View {
        Button(action: action) {
            HStack {
                Text(name)
                Spacer()
                Text("$\(amount, specifier: "%.2f")")
            }
            .font(.subheadline)
        }
    }

    private func investInPendingInvestment(_ investment: InvestmentType) {
        switch investment {
        case .contest(let contest):
            confirmContestInvestment(for: contest)
        case .team(let team):
            // Implement team investment confirmation here
            print("Investing in team: \(team.name)")
        }
        isShowingInvestmentDetail = false
    }

    func declinePendingInvestment(_ investment: InvestmentType) {
        switch investment {
        case .contest(let contest):
            declineContestInvestment(contest: contest) { success in
                if success {
                    // Handle successful decline
                    print("Successfully declined contest investment")
                } else {
                    // Handle failure
                    print("Failed to decline contest investment")
                }
            }
        case .team(let team):
            declineTeamInvestment(team: team) { success in
                if success {
                    // Handle successful decline
                    print("Successfully declined team investment")
                } else {
                    // Handle failure
                    print("Failed to decline team investment")
                }
            }
        }
    }

    private func declineContestInvestment(contest: Contest, completion: @escaping (Bool) -> Void) {
        let contestRef = Firestore.firestore().collection("contests").document(contest.id)
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
        let teamRef = Firestore.firestore().collection("teams").document(team.id)
        teamRef.updateData(["investmentStatus": "Declined"]) { error in
            if let error = error {
                print("Error declining team: \(error)")
                completion(false)
            } else {
                completion(true)
            }
        }
    }



    
    var stripeAccountStatusView: some View {
        HStack {
            if viewModel.stripeAccountStatus == "checking" {
                ProgressView()
                    .padding(.trailing, 5)
                Text("Checking account status...")
            } else if viewModel.stripeAccountStatus == "active" {
                Text("Stripe Connected Account: \(viewModel.maskedExternalAccount)")
                    .font(.footnote)
                    .foregroundColor(.secondary)
            }
        }
        .padding(.horizontal)
    }

    func balanceRow(title: String, amount: Double) -> some View {
        HStack {
            Text(title)
                .font(.headline)
            Spacer()
            Text("$\(amount, specifier: "%.2f")")
                .font(.title3)
                .fontWeight(.semibold)
        }
    }

    // Deposit Button
        var depositButton: some View {
            Button(action: {
                showDepositOptions()
            }) {
                Text("Deposit")
                    .font(.body)
                    .foregroundColor(.white)
                    .frame(maxWidth: .infinity, maxHeight: 10)
                    .padding()
                    .background(Color.gray.opacity(0.1))
                    .cornerRadius(10)
            }
            .disabled(isProcessingPayment)
        }

        // Withdraw Button
        var withdrawButton: some View {
            Button(action: {
                if viewModel.stripeAccountStatus == "active" {
                    // User has connected a bank account, initiate withdrawal process
                    showWithdrawOptions()
                } else {
                    // User has not connected a bank account, initiate account connection
                    createOrContinueStripeAccount()
                }
            }) {
                Text("Withdraw")
                    .font(.body)
                    .foregroundColor(.white)
                    .frame(maxWidth: .infinity, maxHeight: 10)
                    .padding()
                    .background(Color.gray.opacity(0.1))
                    .cornerRadius(10)
            }
            .disabled(isProcessingPayment)
        }
    
    var investButton: some View {
            Button(action: {
                showingInvestmentMenu = true
            }) {
                Text("Invest")
                    .font(.body)
                    .foregroundColor(.white)
                    .frame(maxWidth: .infinity, maxHeight: 10)
                    .padding()
                    .background(Color.gray.opacity(0.1))
                    .cornerRadius(10)
            }
            .actionSheet(isPresented: $showingInvestmentMenu) {
                ActionSheet(title: Text("Investment Options"), buttons: [
                    .default(Text("Invest in Yourself")) {
                        showCreatePersonalInvestment = true
                    },
                    .default(Text("Invest in a Contest")) {
                        showCreateCompetition = true
                    },
                    .default(Text("Invest in a Team")) {
                        alertMessage = "This option is not available yet."
                        showingAlert = true
                    },
                    .cancel()
                ])
            }
        }
        

    
    
    private func createOrContinueStripeAccount() {
        viewModel.createOrRetrieveStripeAccount { result in
            switch result {
            case .success(let url):
                DispatchQueue.main.async {
                    self.safariURL = url
                    // Add a short delay to ensure the sheet triggers correctly
                    DispatchQueue.main.asyncAfter(deadline: .now() + 0.2) {
                        self.showingSafari = true
                    }
                }
            case .failure(let error):
                DispatchQueue.main.async {
                    self.alertMessage = "Failed to create Stripe account: \(error.localizedDescription)"
                    self.showingAlert = true
                }
            }
        }
    }



    private func showDepositOptions() {
        let alert = UIAlertController(title: "Select Deposit Amount", message: nil, preferredStyle: .actionSheet)
        
        let predefinedAmounts = [10, 50, 100, 250, 500]
        for amount in predefinedAmounts {
            alert.addAction(UIAlertAction(title: "$\(amount)", style: .default, handler: { _ in
                self.selectedDepositAmount = Double(amount)
                self.initializePaymentSheet(for: Double(amount))
            }))
        }

        alert.addAction(UIAlertAction(title: "Other", style: .default, handler: { _ in
            self.showCustomAmountAlert()
        }))

        alert.addAction(UIAlertAction(title: "Cancel", style: .cancel))

        if let windowScene = UIApplication.shared.connectedScenes.first as? UIWindowScene,
           let rootViewController = windowScene.windows.first?.rootViewController {
            rootViewController.present(alert, animated: true, completion: nil)
        }
    }

    private func showCustomAmountAlert() {
        let alert = UIAlertController(title: "Enter Custom Amount", message: nil, preferredStyle: .alert)

        alert.addTextField { textField in
            textField.placeholder = "Amount"
            textField.keyboardType = .decimalPad
        }

        alert.addAction(UIAlertAction(title: "Deposit", style: .default, handler: { _ in
            if let amountText = alert.textFields?.first?.text, let amount = Double(amountText) {
                self.processDeposit(amount: amount)
            } else {
                self.alertMessage = "Please enter a valid amount"
                self.showingAlert = true
            }
        }))

        alert.addAction(UIAlertAction(title: "Cancel", style: .cancel))

        if let windowScene = UIApplication.shared.connectedScenes.first as? UIWindowScene,
           let rootViewController = windowScene.windows.first?.rootViewController {
            rootViewController.present(alert, animated: true, completion: nil)
        }

    }

    private func initializePaymentSheet(for amount: Double) {
        guard !isProcessingPayment else {
            print("LOG: Request already in progress. Please wait.")
            return
        }

        print("LOG: Initializing payment sheet for amount: $\(amount)")
        isProcessingPayment = true

        let amountInCents = Int(amount * 100)  // Convert to cents for Stripe

        viewModel.initializePaymentSheet(amount: Double(amountInCents)) { success, message in
            DispatchQueue.main.async {
                self.isProcessingPayment = false
                if success, let paymentSheet = self.viewModel.paymentSheet {
                    self.presentPaymentSheet(paymentSheet)
                } else {
                    self.alertMessage = message ?? "Unable to create payment sheet"
                    self.showingAlert = true
                }
            }
        }
    }

    private func presentPaymentSheet(_ paymentSheet: PaymentSheet) {
        if let windowScene = UIApplication.shared.connectedScenes.first as? UIWindowScene,
           let rootViewController = windowScene.windows.first?.rootViewController {
            paymentSheet.present(from: rootViewController) { result in
                self.handlePaymentResult(result)
            }
        } else {
            self.alertMessage = "Unable to present payment sheet"
            self.showingAlert = true
        }
    }

    private func handlePaymentResult(_ result: PaymentSheetResult) {
        switch result {
        case .completed:
            print("LOG: Payment completed successfully.")
            if let amount = selectedDepositAmount {
                self.processDeposit(amount: amount)
            }
        case .failed(let error):
            print("LOG: Payment failed with error: \(error.localizedDescription)")
            self.alertMessage = "Payment failed: \(error.localizedDescription)"
            self.showingAlert = true
        case .canceled:
            print("LOG: Payment was canceled by the user.")
            self.alertMessage = "Payment canceled"
            self.showingAlert = true
        }
    }

    private func processDeposit(amount: Double) {
        viewModel.confirmPayment(amount: amount) { result in
            switch result {
            case .success:
                self.alertMessage = "Payment successful and balance updated."
                self.showingAlert = true
            case .failure(let error):
                self.alertMessage = "Payment was processed, but failed to update balance: \(error.localizedDescription). Please contact support."
                self.showingAlert = true
            }
        }
    }

    private func showWithdrawOptions() {
        let alert = UIAlertController(title: "Enter Withdraw Amount", message: nil, preferredStyle: .alert)

        alert.addTextField { textField in
            textField.placeholder = "Amount"
            textField.keyboardType = .decimalPad
        }

        alert.addAction(UIAlertAction(title: "Withdraw", style: .default, handler: { _ in
            if let amountText = alert.textFields?.first?.text, let amount = Double(amountText) {
                self.processWithdrawal(amount: amount)
            } else {
                self.alertMessage = "Please enter a valid amount"
                self.showingAlert = true
            }
        }))

        alert.addAction(UIAlertAction(title: "Cancel", style: .cancel))

        if let windowScene = UIApplication.shared.connectedScenes.first as? UIWindowScene,
           let rootViewController = windowScene.windows.first?.rootViewController {
            rootViewController.present(alert, animated: true, completion: nil)
        }
    }

    private func processWithdrawal(amount: Double) {
        // Ensure the withdrawal amount does not exceed the free balance
        guard amount <= freeBalance else {
            self.alertMessage = "You can only withdraw up to your available Free Balance."
            self.showingAlert = true
            return
        }

        guard !isProcessingPayment else {
            print("Request already in progress. Please wait.")
            return
        }

        isProcessingPayment = true
        print("Processing withdrawal of \(amount)")

        viewModel.initiateStripeWithdrawal(amount: Int(amount * 100)) { result in
            self.isProcessingPayment = false

            switch result {
            case .success(let transferId):
                print("Withdrawal successful: \(transferId)")
                self.alertMessage = "Withdrawal successful. Transfer ID: \(transferId)"
                // Update balances after successful withdrawal
                UserBalanceManager.shared.updateUserBalances(userId: self.viewModel.userId, totalBalance: self.totalBalance - amount, investedBalance: self.investedBalance, freeBalance: self.freeBalance - amount) { error in
                    if let error = error {
                        print("Error updating balances after withdrawal: \(error)")
                    }
                }
            case .failure(let error):
                print("Withdrawal failed: \(error.localizedDescription)")
                self.alertMessage = "Failed to process withdrawal: \(error.localizedDescription)"
            }
            self.showingAlert = true
        }
    }

    private func confirmContestInvestment(for contest: Contest) {
            guard let userEmail = Auth.auth().currentUser?.email else { return }
            
            let db = Firestore.firestore()
            let contestRef = db.collection("contests").document(contest.id)
            let investmentRef = contestRef.collection("Investments").document(userEmail)
            
            db.runTransaction({ (transaction, errorPointer) -> Any? in
                let contestDocument: DocumentSnapshot
                do {
                    try contestDocument = transaction.getDocument(contestRef)
                } catch let fetchError as NSError {
                    errorPointer?.pointee = fetchError
                    return nil
                }
                
                guard let currentInvestedParticipants = contestDocument.data()?["investedParticipants"] as? Int else {
                    let error = NSError(domain: "AppErrorDomain", code: -1, userInfo: [NSLocalizedDescriptionKey: "Unable to retrieve invested participants count"])
                    errorPointer?.pointee = error
                    return nil
                }
                
                transaction.updateData(["investmentStatus": "Invested", "investedAt": FieldValue.serverTimestamp()], forDocument: investmentRef)
                transaction.updateData(["investedParticipants": currentInvestedParticipants + 1], forDocument: contestRef)
                
                if currentInvestedParticipants + 1 == contest.totalParticipants {
                    transaction.updateData(["status": "Active"], forDocument: contestRef)
                }
                
                return nil
            }) { (_, error) in
                if let error = error {
                    print("Transaction failed: \(error)")
                    self.alertMessage = "Failed to invest in the contest"
                    self.showingAlert = true
                } else {
                    // Update user's balance
                    UserBalanceManager.shared.updateBalancesAfterInvestment(userId: self.viewModel.userId, investmentAmount: contest.investmentAmount) { error in
                        if let error = error {
                            print("Error updating balances after investment: \(error)")
                            self.alertMessage = "Failed to update balances after investment"
                            self.showingAlert = true
                        } else {
                            self.pendingContestInvestment = nil
                            self.alertMessage = "Successfully invested in the contest"
                            self.showingAlert = true
                        }
                    }
                }
            }
        }

        private func checkPendingContestInvestments() {
            guard let userEmail = Auth.auth().currentUser?.email else { return }
            
            let db = Firestore.firestore()
            db.collectionGroup("Investments")
                .whereField("email", isEqualTo: userEmail)
                .whereField("investmentStatus", isEqualTo: "Pending")
                .getDocuments { snapshot, error in
                    if let error = error {
                        print("Error fetching pending investments: \(error)")
                    } else if let documents = snapshot?.documents, let firstPending = documents.first {
                        let contestId = firstPending.reference.parent.parent?.documentID
                        if let contestId = contestId {
                            db.collection("contests").document(contestId).getDocument { (contestDoc, error) in
                                if let error = error {
                                    print("Error fetching contest: \(error)")
                                } else if let contestData = contestDoc?.data() {
                                    self.pendingContestInvestment = Contest(id: contestId, data: contestData)
                                }
                            }
                        }
                    }
                }
        }
    
}


struct Team: Identifiable {
    var id: String
    var name: String
    var investmentAmount: Double

    init(id: String, data: [String: Any]) {
        self.id = id
        self.name = data["name"] as? String ?? "Unknown"
        self.investmentAmount = data["investmentAmount"] as? Double ?? 0
    }
}


struct InvestmentDetailsView: View {
    @Binding var selectedMonth: String
    @Binding var showInvestmentDetails: Bool
    @ObservedObject var viewModel: BankViewModel
    @State private var isProcessing = false
    @State private var showAlert = false
    @State private var alertMessage = ""
    
    let months = [
        "September 2024", "October 2024", "November 2024", "December 2024",
        "January 2025", "February 2025", "March 2025", "April 2025", "May 2025", "June 2025", "July 2025", "August 2025"
    ]
    
    var body: some View {
            VStack {
                Text("Invest in Yourself")
                    .font(.title)
                    .padding()

                Form {
                    Picker("Select Month", selection: $selectedMonth) {
                        Text("Please select a month").tag("") // Placeholder
                        ForEach(months, id: \.self) { month in
                            Text(month)
                        }
                    }
                    .pickerStyle(MenuPickerStyle()) // This changes it to a dropdown
                    .padding()
                    .onChange(of: selectedMonth) {
                        if selectedMonth.isEmpty {
                            selectedMonth = "Please select a month"
                        }
                    }


                    Text("Amount: $100")
                        .font(.headline)
                        .padding()

                    Text("Invest $100 to earn back $150!")
                        .font(.subheadline)
                        .padding()
                    
                    if viewModel.freeBalance < 100 {
                                        Text("Your Free Balance is too low to make this investment. Make a deposit to continue with this investment.")
                                            .foregroundColor(.red)
                                            .font(.body)
                                            .padding()
                                    }
                }

                Button(action: confirmInvestment) {
                    Text("Confirm Investment")
                        .font(.headline)
                        .foregroundColor(.white)
                        .padding()
                        .background(isProcessing || selectedMonth.isEmpty || viewModel.freeBalance < 100 ? Color.gray : Color.green)
                        .cornerRadius(10)
                }
                .disabled(isProcessing || selectedMonth.isEmpty || viewModel.freeBalance < 100) // Disable if insufficient balance or no month selected
                .padding()
            }
            .alert(isPresented: $showAlert) {
                Alert(title: Text("Error"), message: Text(alertMessage), dismissButton: .default(Text("OK")))
            }
        }

        private func confirmInvestment() {
            guard !selectedMonth.isEmpty else {
                alertMessage = "Please select a month before confirming the investment."
                showAlert = true
                return
            }
            
            guard viewModel.freeBalance >= 100 else {
                alertMessage = "Insufficient free balance to make this investment."
                showAlert = true
                return
            }
            
            isProcessing = true
            viewModel.recordInvestment(month: selectedMonth, amount: 100) { success in
                DispatchQueue.main.async {
                    self.isProcessing = false
                    if success {
                        print("Investment recorded successfully")
                        self.showInvestmentDetails = false // Dismiss the view
                    } else {
                        self.alertMessage = "Failed to record investment. Please try again."
                        self.showAlert = true
                    }
                }
            }
        }
    }



struct SafariView: UIViewControllerRepresentable {
    let url: URL
    
    func makeUIViewController(context: Context) -> SFSafariViewController {
        return SFSafariViewController(url: url)
    }
    
    func updateUIViewController(_ uiViewController: SFSafariViewController, context: Context) {}
}


class UserBalanceManager {
    static let shared = UserBalanceManager()
    private init() {}
    
    private let db = Firestore.firestore()
    
    // MARK: - Balance Update Functions
    
    func updateUserBalances(userId: String, totalBalance: Double, investedBalance: Double, freeBalance: Double, completion: @escaping (Error?) -> Void) {
        let userRef = db.collection("users").document(userId)
        
        userRef.updateData([
            "totalBalance": totalBalance,
            "investedBalance": investedBalance,
            "freeBalance": freeBalance
        ]) { error in
            if let error = error {
                print("Error updating balances: \(error)")
            } else {
                print("Balances updated successfully")
            }
            completion(error)
        }
    }
    
    func updateBalancesAfterInvestment(userId: String, investmentAmount: Double, completion: @escaping (Error?) -> Void) {
        let userRef = db.collection("users").document(userId)
        
        db.runTransaction({ (transaction, errorPointer) -> Any? in
            let userDocument: DocumentSnapshot
            do {
                try userDocument = transaction.getDocument(userRef)
            } catch let fetchError as NSError {
                errorPointer?.pointee = fetchError
                return nil
            }
            
            guard let oldTotalBalance = userDocument.data()?["totalBalance"] as? Double,
                  let oldInvestedBalance = userDocument.data()?["investedBalance"] as? Double else {
                let error = NSError(domain: "AppErrorDomain", code: -1, userInfo: [NSLocalizedDescriptionKey: "Unable to retrieve user balances"])
                errorPointer?.pointee = error
                return nil
            }
            
            let newInvestedBalance = oldInvestedBalance + investmentAmount
            let newFreeBalance = oldTotalBalance - newInvestedBalance
            
            transaction.updateData([
                "investedBalance": newInvestedBalance,
                "freeBalance": newFreeBalance
            ], forDocument: userRef)
            
            return nil
        }) { (object, error) in
            if let error = error {
                print("Transaction failed: \(error)")
            } else {
                print("Transaction successfully committed!")
            }
            completion(error)
        }
    }
    
    // MARK: - Balance Retrieval Functions
    
    func getUserBalances(userId: String, completion: @escaping (Double, Double, Double, Error?) -> Void) {
        let userRef = db.collection("users").document(userId)
        
        userRef.getDocument { (document, error) in
            if let document = document, document.exists {
                let totalBalance = document.data()?["totalBalance"] as? Double ?? 0
                let investedBalance = document.data()?["investedBalance"] as? Double ?? 0
                let freeBalance = document.data()?["freeBalance"] as? Double ?? 0
                completion(totalBalance, investedBalance, freeBalance, nil)
            } else {
                completion(0, 0, 0, error)
            }
        }
    }
    
    // MARK: - Balance Listener
    
    func listenForBalanceUpdates(userId: String, updateHandler: @escaping (Double, Double, Double) -> Void) -> ListenerRegistration {
        let userRef = db.collection("users").document(userId)
        
        return userRef.addSnapshotListener { documentSnapshot, error in
            guard let document = documentSnapshot else {
                print("Error fetching document: \(error!)")
                return
            }
            guard let data = document.data() else {
                print("Document data was empty.")
                return
            }
            let totalBalance = data["totalBalance"] as? Double ?? 0
            let investedBalance = data["investedBalance"] as? Double ?? 0
            let freeBalance = data["freeBalance"] as? Double ?? 0
            
            updateHandler(totalBalance, investedBalance, freeBalance)
        }
    }
    
    // MARK: - User Initialization
    
    func initializeNewUserBalances(userId: String, completion: @escaping (Error?) -> Void) {
        let userRef = db.collection("users").document(userId)
        
        userRef.setData([
            "totalBalance": 0,
            "investedBalance": 0,
            "freeBalance": 0
        ], merge: true) { error in
            if let error = error {
                print("Error initializing user balances: \(error)")
            } else {
                print("User balances initialized successfully")
            }
            completion(error)
        }
    }
}




#Preview {
    BankView()
}
