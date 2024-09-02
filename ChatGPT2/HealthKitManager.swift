//
//  HealthKitManager.swift
//  ChatGPT2
//
//  Created by Ryan Whooley on 8/25/24.
//

import Foundation
import HealthKit
import CoreLocation

class HealthKitManager: ObservableObject {
    let healthStore = HKHealthStore()
    @Published var isAuthorized = false
    @Published var workouts: [DetailedWorkout] = []
    
    init() {
        checkAuthorizationStatus()
    }
    
    func checkAuthorizationStatus() {
        guard HKHealthStore.isHealthDataAvailable() else {
            print("HealthKit is not available on this device")
            DispatchQueue.main.async {
                self.isAuthorized = false
            }
            return
        }
        
        let typesToRead: Set = [
            HKObjectType.workoutType(),
            HKObjectType.quantityType(forIdentifier: .stepCount)!,
            HKObjectType.quantityType(forIdentifier: .activeEnergyBurned)!,
            HKObjectType.quantityType(forIdentifier: .distanceWalkingRunning)!,
            HKObjectType.quantityType(forIdentifier: .heartRate)!,
            HKSeriesType.workoutRoute()
        ]
        
        healthStore.getRequestStatusForAuthorization(toShare: [], read: typesToRead) { (status, error) in
            DispatchQueue.main.async {
                if let error = error {
                    print("Error checking authorization status: \(error.localizedDescription)")
                    self.isAuthorized = false
                    return
                }
                
                switch status {
                case .unnecessary:
                    print("HealthKit authorization not required (already authorized)")
                    self.isAuthorized = true
                default:
                    print("HealthKit authorization required")
                    self.isAuthorized = false
                }
            }
        }
    }
    
    func requestFullAuthorization(completion: @escaping (Bool, Error?) -> Void) {
        guard HKHealthStore.isHealthDataAvailable() else {
            print("HealthKit is not available on this device")
            completion(false, NSError(domain: "HealthKitManager", code: 0, userInfo: [NSLocalizedDescriptionKey: "HealthKit is not available on this device"]))
            return
        }
        
        let typesToRead: Set = [
            HKObjectType.workoutType(),
            HKObjectType.quantityType(forIdentifier: .stepCount)!,
            HKObjectType.quantityType(forIdentifier: .activeEnergyBurned)!,
            HKObjectType.quantityType(forIdentifier: .distanceWalkingRunning)!,
            HKObjectType.quantityType(forIdentifier: .heartRate)!,
            HKSeriesType.workoutRoute()
        ]
        
        healthStore.requestAuthorization(toShare: [], read: typesToRead) { success, error in
            DispatchQueue.main.async {
                if success {
                    print("Authorization successful")
                } else {
                    print("Authorization failed: \(error?.localizedDescription ?? "Unknown error")")
                }
                self.isAuthorized = success
                completion(success, error)
            }
        }
    }
    
    func fetchAllDetailedWorkouts(completion: @escaping ([DetailedWorkout], Error?) -> Void) {
        guard isAuthorized else {
            print("Not authorized to fetch workouts")
            completion([], NSError(domain: "HealthKitManager", code: 0, userInfo: [NSLocalizedDescriptionKey: "Not authorized"]))
            return
        }
        
        let workoutType = HKObjectType.workoutType()
        let sortDescriptor = NSSortDescriptor(key: HKSampleSortIdentifierStartDate, ascending: false)
        
        let query = HKSampleQuery(sampleType: workoutType, predicate: nil, limit: HKObjectQueryNoLimit, sortDescriptors: [sortDescriptor]) { (query, samples, error) in
            DispatchQueue.main.async {
                guard let workouts = samples as? [HKWorkout], error == nil else {
                    completion([], error)
                    return
                }
                
                let detailedWorkouts = workouts.compactMap { workout -> DetailedWorkout? in
                    let averageHeartRate = workout.statistics(for: HKQuantityType.quantityType(forIdentifier: .heartRate)!)?.averageQuantity()?.doubleValue(for: .count().unitDivided(by: .minute()))
                    let stepsCount = workout.statistics(for: HKQuantityType.quantityType(forIdentifier: .stepCount)!)?.sumQuantity()?.doubleValue(for: .count())
                    let pace = workout.totalDistance?.doubleValue(for: .meter()) ?? 0 / workout.duration
                    
                    return DetailedWorkout(
                        id: UUID(),
                        type: workout.workoutActivityType,
                        distance: workout.totalDistance?.doubleValue(for: .meter()) ?? 0,
                        duration: workout.duration,
                        calories: workout.totalEnergyBurned?.doubleValue(for: .kilocalorie()),
                        date: workout.startDate,
                        averageHeartRate: averageHeartRate,
                        stepsCount: stepsCount,
                        pace: pace,
                        startLocation: nil,
                        endLocation: nil
                    )
                }
                
                self.workouts = detailedWorkouts
                completion(detailedWorkouts, nil)
            }
        }
        
        healthStore.execute(query)
    }
}
