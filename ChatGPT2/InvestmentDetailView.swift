//
//  InvestmentDetailView.swift
//  ChatGPT2
//
//  Created by Ryan Whooley on 9/17/24.
//

import SwiftUI

struct InvestmentDetailView: View {
    let investment: InvestmentType
    let onInvest: () -> Void
    let onDecline: () -> Void

    enum InvestmentType {
        case contest(Contest)
        case team(Team)
    }

    
    var body: some View {
        VStack {
            switch investment {
            case .contest(let contest):
                Text("Contest: \(contest.contestName)")
                Text("Investment: \(contest.investmentAmount)")

            case .team(let team):
                Text("Team: \(team.name)")
                Text("Investment: \(team.investmentAmount)")
            }

            Button(action: onInvest) {
                Text("Invest")
            }

            Button(action: onDecline) {
                Text("Decline")
            }
        }
    }
}

    
    private func formatDate(_ date: Date) -> String {
        let formatter = DateFormatter()
        formatter.dateStyle = .medium
        return formatter.string(from: date)
    }



