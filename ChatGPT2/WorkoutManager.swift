//
//  WorkoutManager.swift
//  ChatGPT2
//
//  Created by Ryan Whooley on 8/25/24.
//

import Foundation
import HealthKit

class WorkoutManager: NSObject, ObservableObject {
    @Published var isWorkoutInProgress = false
    @Published var elapsedTime: TimeInterval = 0
    @Published var distance: Double = 0
    @Published var calories: Double = 0
    @Published var heartRate: Double = 0
    @Published var workoutType: HKWorkoutActivityType?
    
    private var healthStore: HKHealthStore?
    private var timer: Timer?
    private var startDate: Date?
    
    private var distanceQuery: HKQuery?
    private var caloriesQuery: HKQuery?
    private var heartRateQuery: HKQuery?
    
    override init() {
        super.init()
        if HKHealthStore.isHealthDataAvailable() {
            healthStore = HKHealthStore()
        }
    }
    
    func requestAuthorization(completion: @escaping (Bool, Error?) -> Void) {
        guard let healthStore = self.healthStore else {
            completion(false, nil)
            return
        }
        
        let typesToShare: Set = [HKObjectType.workoutType()]
        let typesToRead: Set = [
            HKObjectType.quantityType(forIdentifier: .heartRate)!,
            HKObjectType.quantityType(forIdentifier: .activeEnergyBurned)!,
            HKObjectType.quantityType(forIdentifier: .distanceWalkingRunning)!,
            HKObjectType.quantityType(forIdentifier: .distanceCycling)!
        ]
        
        healthStore.requestAuthorization(toShare: typesToShare, read: typesToRead) { success, error in
            DispatchQueue.main.async {
                completion(success, error)
            }
        }
    }
    
    func startWorkout(workoutType: HKWorkoutActivityType) {
        self.workoutType = workoutType
        startDate = Date()
        isWorkoutInProgress = true
        startTimer()
        startQueries()
    }
    
    func endWorkout() {
        guard let startDate = startDate, let workoutType = workoutType else { return }
        
        stopTimer()
        stopQueries()
        isWorkoutInProgress = false
        
        let endDate = Date()
        let workout = HKWorkout(activityType: workoutType,
                                start: startDate,
                                end: endDate,
                                duration: endDate.timeIntervalSince(startDate),
                                totalEnergyBurned: HKQuantity(unit: .kilocalorie(), doubleValue: calories),
                                totalDistance: HKQuantity(unit: .meter(), doubleValue: distance),
                                metadata: nil)
        
        healthStore?.save(workout) { (success, error) in
            if let error = error {
                print("Error saving workout: \(error.localizedDescription)")
            } else {
                print("Workout saved successfully")
            }
        }
        
        resetWorkoutMetrics()
    }
    
    private func startTimer() {
        timer = Timer.scheduledTimer(withTimeInterval: 1.0, repeats: true) { [weak self] _ in
            guard let self = self, let startDate = self.startDate else { return }
            self.elapsedTime = Date().timeIntervalSince(startDate)
        }
    }
    
    private func stopTimer() {
        timer?.invalidate()
        timer = nil
    }
    
    private func startQueries() {
        startDistanceQuery()
        startCaloriesQuery()
        startHeartRateQuery()
    }
    
    private func stopQueries() {
        if let distanceQuery = distanceQuery {
            healthStore?.stop(distanceQuery)
        }
        if let caloriesQuery = caloriesQuery {
            healthStore?.stop(caloriesQuery)
        }
        if let heartRateQuery = heartRateQuery {
            healthStore?.stop(heartRateQuery)
        }
        
        distanceQuery = nil
        caloriesQuery = nil
        heartRateQuery = nil
    }
    
    private func startDistanceQuery() {
        guard let startDate = startDate else { return }
        
        let distanceType = workoutType == .cycling ?
            HKObjectType.quantityType(forIdentifier: .distanceCycling)! :
            HKObjectType.quantityType(forIdentifier: .distanceWalkingRunning)!
        
        let predicate = HKQuery.predicateForSamples(withStart: startDate, end: nil, options: .strictStartDate)
        
        let query = HKAnchoredObjectQuery(type: distanceType, predicate: predicate, anchor: nil, limit: HKObjectQueryNoLimit) { [weak self] (query, samples, deletedObjects, anchor, error) in
            self?.processDistanceSamples(samples as? [HKQuantitySample])
        }
        
        query.updateHandler = { [weak self] (query, samples, deletedObjects, anchor, error) in
            self?.processDistanceSamples(samples as? [HKQuantitySample])
        }
        
        healthStore?.execute(query)
        distanceQuery = query
    }
    
    private func startCaloriesQuery() {
        guard let startDate = startDate else { return }
        
        let caloriesType = HKObjectType.quantityType(forIdentifier: .activeEnergyBurned)!
        let predicate = HKQuery.predicateForSamples(withStart: startDate, end: nil, options: .strictStartDate)
        
        let query = HKAnchoredObjectQuery(type: caloriesType, predicate: predicate, anchor: nil, limit: HKObjectQueryNoLimit) { [weak self] (query, samples, deletedObjects, anchor, error) in
            self?.processCaloriesSamples(samples as? [HKQuantitySample])
        }
        
        query.updateHandler = { [weak self] (query, samples, deletedObjects, anchor, error) in
            self?.processCaloriesSamples(samples as? [HKQuantitySample])
        }
        
        healthStore?.execute(query)
        caloriesQuery = query
    }
    
    private func startHeartRateQuery() {
        guard let startDate = startDate else { return }
        
        let heartRateType = HKObjectType.quantityType(forIdentifier: .heartRate)!
        let predicate = HKQuery.predicateForSamples(withStart: startDate, end: nil, options: .strictStartDate)
        
        let query = HKAnchoredObjectQuery(type: heartRateType, predicate: predicate, anchor: nil, limit: HKObjectQueryNoLimit) { [weak self] (query, samples, deletedObjects, anchor, error) in
            self?.processHeartRateSamples(samples as? [HKQuantitySample])
        }
        
        query.updateHandler = { [weak self] (query, samples, deletedObjects, anchor, error) in
            self?.processHeartRateSamples(samples as? [HKQuantitySample])
        }
        
        healthStore?.execute(query)
        heartRateQuery = query
    }
    
    private func processDistanceSamples(_ samples: [HKQuantitySample]?) {
        guard let samples = samples else { return }
        
        DispatchQueue.main.async {
            let newDistance = samples.reduce(0.0) { $0 + $1.quantity.doubleValue(for: .meter()) }
            self.distance += newDistance
        }
    }
    
    private func processCaloriesSamples(_ samples: [HKQuantitySample]?) {
        guard let samples = samples else { return }
        
        DispatchQueue.main.async {
            let newCalories = samples.reduce(0.0) { $0 + $1.quantity.doubleValue(for: .kilocalorie()) }
            self.calories += newCalories
        }
    }
    
    private func processHeartRateSamples(_ samples: [HKQuantitySample]?) {
        guard let samples = samples, let lastSample = samples.last else { return }
        
        DispatchQueue.main.async {
            self.heartRate = lastSample.quantity.doubleValue(for: HKUnit.count().unitDivided(by: .minute()))
        }
    }
    
    private func resetWorkoutMetrics() {
        elapsedTime = 0
        distance = 0
        calories = 0
        heartRate = 0
        startDate = nil
        workoutType = nil
    }
}
