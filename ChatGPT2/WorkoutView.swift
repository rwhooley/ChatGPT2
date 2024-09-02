//
//  WorkoutView.swift
//  ChatGPT2
//
//  Created by Ryan Whooley on 8/25/24.
//

import SwiftUI
import HealthKit

struct WorkoutView: View {
    @ObservedObject var workoutManager: WorkoutManager
    @Binding var isPresented: Bool
    @State private var showingAlert = false
    @State private var alertMessage = ""
    
    var body: some View {
        VStack {
            Text(workoutManager.workoutType.map { HKWorkoutActivityType.name(for: $0) } ?? "Workout")
                .font(.largeTitle)
            
            HStack {
                DataDisplayView(title: "Time", value: formatTime(workoutManager.elapsedTime))
                DataDisplayView(title: "Distance", value: String(format: "%.2f km", workoutManager.distance / 1000))
            }
            
            HStack {
                DataDisplayView(title: "Calories", value: String(format: "%.0f kcal", workoutManager.calories))
                DataDisplayView(title: "Heart Rate", value: String(format: "%.0f bpm", workoutManager.heartRate))
            }
            
            Button(action: {
                workoutManager.endWorkout()
                isPresented = false
            }) {
                Text("End Workout")
                    .font(.headline)
                    .foregroundColor(.white)
                    .padding()
                    .background(Color.red)
                    .cornerRadius(10)
            }
            .padding()
        }
        .onAppear {
            requestAuthorizationAndStartWorkout()
        }
        .alert(isPresented: $showingAlert) {
            Alert(title: Text("Error"), message: Text(alertMessage), dismissButton: .default(Text("OK")))
        }
    }
    
    private func requestAuthorizationAndStartWorkout() {
        workoutManager.requestAuthorization { (success, error) in
            if success {
                if let workoutType = workoutManager.workoutType {
                    workoutManager.startWorkout(workoutType: workoutType)
                }
            } else {
                alertMessage = error?.localizedDescription ?? "Failed to get HealthKit authorization"
                showingAlert = true
            }
        }
    }
    
    private func formatTime(_ timeInterval: TimeInterval) -> String {
        let formatter = DateComponentsFormatter()
        formatter.allowedUnits = [.hour, .minute, .second]
        formatter.zeroFormattingBehavior = .pad
        return formatter.string(from: timeInterval) ?? "00:00:00"
    }
}

struct DataDisplayView: View {
    let title: String
    let value: String
    
    var body: some View {
        VStack {
            Text(title)
                .font(.caption)
            Text(value)
                .font(.title2)
        }
        .frame(minWidth: 0, maxWidth: .infinity)
        .padding()
        .background(Color.gray.opacity(0.1))
        .cornerRadius(10)
    }
}

extension HKWorkoutActivityType {
    static func name(for type: HKWorkoutActivityType) -> String {
        switch type {
        case .running:
            return "Running"
        case .cycling:
            return "Cycling"
        case .walking:
            return "Walking"
        case .swimming:
            return "Swimming"
        case .hiking:
            return "Hiking"
        case .yoga:
            return "Yoga"
        case .functionalStrengthTraining:
            return "Strength Training"
        case .traditionalStrengthTraining:
            return "Weight Training"
        case .crossTraining:
            return "Cross Training"
        case .mixedCardio:
            return "Mixed Cardio"
        default:
            return "Workout"
        }
    }
}

#Preview {
    WorkoutView(workoutManager: WorkoutManager(),
                isPresented: .constant(true)
    )
}
