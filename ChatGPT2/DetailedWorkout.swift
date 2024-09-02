//
//  DetailedWorkout.swift
//  ChatGPT2
//
//  Created by Ryan Whooley on 8/27/24.
//

import Foundation
import HealthKit
import CoreLocation

struct DetailedWorkout: Identifiable {
    let id: UUID
    let type: HKWorkoutActivityType
    let distance: Double
    let duration: TimeInterval
    let calories: Double?
    let date: Date
    let averageHeartRate: Double?
    let stepsCount: Double?
    let pace: Double?
    let startLocation: CLLocationCoordinate2D?
    let endLocation: CLLocationCoordinate2D?
}
