//
//  CollapsiblePersonalPlanView.swift
//  ChatGPT2
//
//  Created by Ryan Whooley on 9/26/24.
//

import SwiftUI
import Firebase
import FirebaseAuth


struct CollapsiblePersonalPlanView: View {
    let personalPlan: PersonalPlan
    @State private var isExpanded = false
    
    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            Button(action: { isExpanded.toggle() }) {
                planHeader
            }
            .buttonStyle(PlainButtonStyle())

            if isExpanded {
                expandedContent
            }
        }
        .padding()
        .background(RoundedRectangle(cornerRadius: 15)
            .fill(Color.green.opacity(0.1))
            .shadow(color: Color.gray.opacity(0.2), radius: 5, x: 0, y: 2))
        .overlay(
            RoundedRectangle(cornerRadius: 15)
                .stroke(Color.green.opacity(0.3), lineWidth: 1)
        )
    }
    
    private var planHeader: some View {
        HStack {
            Text(personalPlan.month)
                .font(.headline)
            Spacer()
            Text(formatCurrency(personalPlan.amount))
                .font(.subheadline)
            Image(systemName: isExpanded ? "chevron.up" : "chevron.down")
        }
    }
    
    private var expandedContent: some View {
        VStack(alignment: .leading, spacing: 8) {
            infoRow(title: "Month", value: personalPlan.month)
            infoRow(title: "Amount", value: formatCurrency(personalPlan.amount))
            infoRow(title: "Timestamp", value: formatDate(personalPlan.timestamp))
        }
        .font(.subheadline)
    }

    private func infoRow(title: String, value: String) -> some View {
        HStack(alignment: .top) {
            Text("\(title):")
                .foregroundColor(.secondary)
                .frame(width: 120, alignment: .leading)
            Text(value)
                .foregroundColor(.primary)
        }
    }

    private func formatDate(_ date: Date?) -> String {
        guard let date = date else { return "N/A" }
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

// Model representing a personal investment plan
struct PersonalPlan: Identifiable {
    let id: String
    let amount: Double
    let month: String
    let timestamp: Date
    let userId: String
}
