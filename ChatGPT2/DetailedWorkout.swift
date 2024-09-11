//
//  DetailedWorkout.swift
//  ChatGPT2
//
//  Created by Ryan Whooley on 8/27/24.
//

import Foundation
import HealthKit
import CoreLocation
import FirebaseFirestore
import FirebaseAuth

var routeImageUrl: String?
var calories: Double?


struct DetailedWorkout: Identifiable {
    let id: UUID
    let type: HKWorkoutActivityType
    let distance: Double
    let duration: TimeInterval
    let calories: Double
    let date: Date
    let averageHeartRate: Double?
    let maxHeartRate: Double?
    let stepsCount: Double?
    let pace: TimeInterval?
    let routeImageUrl: String?
    let intensity: WorkoutIntensity
    let averageCadence: Double?
    let weather: String?
    let sourceName: String?
    let userFirstName: String  // New field
    let userLastName: String   // New field
    let userProfilePictureUrl: String? // New field
}

enum WorkoutIntensity: String {
    case low, moderate, high
}

