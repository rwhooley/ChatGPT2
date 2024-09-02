//
//  DepositView.swift
//  ChatGPT2
//
//  Created by Ryan Whooley on 8/30/24.
//

import SwiftUI
import Firebase
import FirebaseFirestore
import FirebaseAuth
import Stripe
import StripePaymentSheet


struct DepositBankView: View {
    @ObservedObject var viewModel: BankViewModel
    @Binding var isPresented: Bool
    
    @State private var selectedAmount: Double?
    @State private var customAmount: String = ""
    @State private var showingAlert = false
    @State private var alertMessage = ""
    @State private var isProcessingPayment = false

    let predefinedAmounts = [10.0, 50.0, 100.0, 250.0, 500.0]

    var body: some View {
        NavigationView {
            Form {
                Section(header: Text("Select Amount")) {
                    ForEach(predefinedAmounts, id: \.self) { amount in
                        Button(action: {
                            self.selectedAmount = amount
                            self.customAmount = ""
                        }) {
                            HStack {
                                Text("$\(Int(amount))")
                                Spacer()
                                if selectedAmount == amount {
                                    Image(systemName: "checkmark")
                                }
                            }
                        }
                        .foregroundColor(.primary)
                    }
                }

                Section(header: Text("Custom Amount")) {
                    TextField("Enter amount", text: $customAmount)
                        .keyboardType(.decimalPad)
                        .onChange(of: customAmount) { _ in
                            selectedAmount = nil
                        }
                }

                Section {
                    Button(action: {
                        processPayment()
                    }) {
                        Text("Confirm Deposit")
                            .frame(maxWidth: .infinity)
                    }
                    .disabled(isProcessingPayment || (selectedAmount == nil && customAmount.isEmpty))
                }
            }
            .navigationTitle("Deposit")
            .alert(isPresented: $showingAlert) {
                Alert(title: Text("Deposit Result"), message: Text(alertMessage), dismissButton: .default(Text("OK")))
            }
        }
    }

    private func processPayment() {
        let amount = selectedAmount ?? Double(customAmount) ?? 0
        guard amount > 0 else {
            alertMessage = "Please select or enter a valid amount."
            showingAlert = true
            return
        }

        isProcessingPayment = true
        viewModel.initializePaymentSheet(amount: amount) { success, message in
            if success, let paymentSheet = viewModel.paymentSheet {
                presentPaymentSheet(paymentSheet)
            } else {
                alertMessage = message ?? "Unable to create payment sheet"
                showingAlert = true
                isProcessingPayment = false
            }
        }
    }

    private func presentPaymentSheet(_ paymentSheet: PaymentSheet) {
        if let rootViewController = UIApplication.shared.windows.first?.rootViewController {
            paymentSheet.present(from: rootViewController) { result in
                self.handlePaymentResult(result)
            }
        } else {
            alertMessage = "Unable to present payment sheet"
            showingAlert = true
            isProcessingPayment = false
        }
    }

    private func handlePaymentResult(_ result: PaymentSheetResult) {
        switch result {
        case .completed:
            confirmAndUpdateBalance()
        case .failed(let error):
            alertMessage = "Payment failed: \(error.localizedDescription)"
            showingAlert = true
            isProcessingPayment = false
        case .canceled:
            alertMessage = "Payment canceled"
            showingAlert = true
            isProcessingPayment = false
        }
    }

    private func confirmAndUpdateBalance() {
        let amount = selectedAmount ?? Double(customAmount) ?? 0
        viewModel.confirmPayment(amount: amount) { result in
            isProcessingPayment = false
            switch result {
            case .success:
                alertMessage = "Payment successful and balance updated."
                showingAlert = true
                isPresented = false  // Dismiss the view after successful payment
            case .failure(let error):
                alertMessage = "Payment was processed, but failed to update balance: \(error.localizedDescription). Please contact support."
                showingAlert = true
            }
        }
    }
}

struct DepositBankView_Previews: PreviewProvider {
    static var previews: some View {
        DepositBankView(viewModel: BankViewModel(), isPresented: .constant(true))
    }
}
