//
//  HomeTeamsView.swift
//  ChatGPT2
//
//  Created by Ryan Whooley on 9/17/24.
//

import SwiftUI

struct HomeTeamsView: View {
    @State private var activeTeams: [String] = []  // Replace with actual data type

    var body: some View {
        VStack(alignment: .leading, spacing: 20) {
            Text("Teams coming soon!")
                .font(.title2)
                .fontWeight(.bold)
                
            
//            if activeTeams.isEmpty {
//                Text("No active teams.")
//                    .foregroundColor(.gray)
//                    .padding()
//                    .background(RoundedRectangle(cornerRadius: 10).fill(Color.gray.opacity(0.2)))
//            } else {
//                ForEach(activeTeams, id: \.self) { team in
//                    Text(team)
//                        .padding()
//                        .background(RoundedRectangle(cornerRadius: 10).fill(Color.green.opacity(0.2)))
//                }
//            }
//            
//            NavigationLink(destination: CreateTeamView()) {
//                Text("Create New Team")
//                    .font(.headline)
//                    .foregroundColor(.white)
//                    .padding()
//                    .frame(maxWidth: .infinity)
//                    .background(Color.green)
//                    .cornerRadius(10)
//                    .padding(.top, 10)
//            }
        }
    }
}

struct CreateTeamView: View {
    var body: some View {
        Text("Create Team View")
        // Implement the team creation interface
    }
}
