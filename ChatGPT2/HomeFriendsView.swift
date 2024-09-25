//
//  HomeFriendsView.swift
//  ChatGPT2
//
//  Created by Ryan Whooley on 9/17/24.
//

import SwiftUI

struct HomeFriendsView: View {
    var body: some View {
        VStack(alignment: .leading, spacing: 20) {
            Text("Investments in Friends")
                .font(.title2)
                .fontWeight(.bold)
            
            Text("Friends' investments data goes here.")
                .frame(maxWidth: .infinity)
                .padding()
                .background(RoundedRectangle(cornerRadius: 10).fill(Color.gray.opacity(0.2)))

            NavigationLink(destination: CreateFriendInvestmentView()) {
                Text("Invest in a Friend")
                    .font(.headline)
                    .foregroundColor(.white)
                    .padding()
                    .frame(maxWidth: .infinity)
                    .background(Color.green)
                    .cornerRadius(10)
                    .padding(.top, 10)
            }
        }
    }
}

struct CreateFriendInvestmentView: View {
    var body: some View {
        Text("Create Friend Investment View")
        // Implement the friend investment creation interface
    }
}
