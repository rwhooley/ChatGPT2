//
//  SummaryModuleView.swift
//  ChatGPT2
//
//  Created by Ryan Whooley on 9/12/24.
//

import SwiftUI

struct SummaryModuleView: View {
    @State private var selectedTab: SummaryTab = .investments  // Default tab
    
    enum SummaryTab: String, CaseIterable {
        case investments = "Investments"
        case friendsActivity = "Friends"
        case bankBalance = "Bank"
        case todos = "To-Dos"
    }
    
    var body: some View {
        VStack {
            // Tab picker
            Picker("Select Tab", selection: $selectedTab) {
                ForEach(SummaryTab.allCases, id: \.self) { tab in
                    Text(tab.rawValue).tag(tab)
                }
            }
            .pickerStyle(SegmentedPickerStyle())
            .padding([.leading, .trailing])

            // Display content based on the selected tab
            switch selectedTab {
            case .investments:
                investmentsSummary
            case .friendsActivity:
                friendsActivitySummary
            case .bankBalance:
                bankBalanceSummary
            case .todos:
                todosSummary
            }
        }
        .padding()
        .background(RoundedRectangle(cornerRadius: 10).fill(Color.gray.opacity(0.2)))
        .frame(height: 100)  // Constrain the height to about 1 inch (~100 points)
    }
    
    // Investments Summary View
    private var investmentsSummary: some View {
        VStack {
            Text("Personal: $150.00")  // Placeholder data
            Text("Group: $200.00")
            Text("Friends: $50.00")
        }
    }
    
    // Friends' Recent Activity Summary View
    private var friendsActivitySummary: some View {
        VStack {
            Text("John completed a 5-mile run")
            Text("Emily joined a new challenge")
        }
    }
    
    // Bank Balance Summary View
    private var bankBalanceSummary: some View {
        VStack {
            Text("Total Balance: $500.00")
        }
    }
    
    // Pending To-Dos Summary View
    private var todosSummary: some View {
        VStack {
            Text("• Complete 2 more workouts")
            Text("• Withdraw earned money")
        }
    }
}

#Preview {
    SummaryModuleView()
}
