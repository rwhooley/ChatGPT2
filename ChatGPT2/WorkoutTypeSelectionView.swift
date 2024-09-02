//
//  WorkoutTypeSelection.swift
//  ChatGPT2
//
//  Created by Ryan Whooley on 8/25/24.
//

import SwiftUI
import HealthKit

struct WorkoutTypeSelectionView: View {
    @Binding var isPresented: Bool
    @Binding var selectedWorkoutType: HKWorkoutActivityType?

    let workoutTypes: [(String, HKWorkoutActivityType)] = [
        ("Running", .running),
        ("Cycling", .cycling),
        // Add more workout types as needed
    ]
    
    var body: some View {
        NavigationView {
            VStack(alignment: .center, spacing: 20) {
                List(workoutTypes, id: \.1) { workoutType in
                    Button(action: {
                        // Action is disabled
                    }) {
                        Text(workoutType.0)
                    }
                    .disabled(true) // Disable the button
                }
                .listStyle(PlainListStyle()) // Remove default list styling
                
                VStack(alignment: .center, spacing: 10) {
                    Text("This feature is under development!")
                        .font(.headline)
                        .foregroundColor(.red)
                        .multilineTextAlignment(.center)
                    
                    Text("For now, connect your Strava account to Apple Health and record your workouts on Strava. The Antelope app will automatically collect these workouts and they will appear in your Performance section.")
                        .font(.subheadline)
                        .foregroundColor(.gray)
                        .multilineTextAlignment(.center)
                        .fixedSize(horizontal: false, vertical: true)
                }
                .padding()
            }
            .navigationTitle("Select Workout Type")
        }
    }
}

#Preview {
    WorkoutTypeSelectionView(isPresented: .constant(true),
                             selectedWorkoutType: .constant(nil))
}
