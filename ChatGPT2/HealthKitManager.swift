//
//  HealthKitManager.swift
//  ChatGPT2
//
//  Created by Ryan Whooley on 8/25/24.
//

import Foundation
import HealthKit
import CoreLocation
import FirebaseFirestore
import FirebaseAuth

class HealthKitManager: ObservableObject {
    let healthStore = HKHealthStore()
    @Published var isAuthorized = false
    @Published var workouts: [DetailedWorkout] = []
    @Published var lastSyncDate: Date?
    public let db = Firestore.firestore()
    public func getCurrentUserId() -> String? {
            return Auth.auth().currentUser?.uid
        }
    
    init() {
        checkAuthorizationStatus()
        loadLastSyncDate()
    }
    
    private func loadLastSyncDate() {
            if let date = UserDefaults.standard.object(forKey: "lastWorkoutSyncDate") as? Date {
                self.lastSyncDate = date
            }
        }

        public func resetLastSyncDate() {
            UserDefaults.standard.removeObject(forKey: "lastWorkoutSyncDate")
            self.lastSyncDate = nil
            print("Last sync date has been reset")
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
        let workoutType = HKObjectType.workoutType()
        
        print("Fetching workouts from HealthKit...")
        
        // Use the last sync date to optimize fetching only new workouts
        let predicate = HKQuery.predicateForSamples(withStart: lastSyncDate, end: Date())
        
        let query = HKSampleQuery(sampleType: workoutType, predicate: predicate, limit: HKObjectQueryNoLimit, sortDescriptors: nil) { (query, samples, error) in
            guard let workouts = samples as? [HKWorkout], error == nil else {
                print("Error fetching workouts: \(error?.localizedDescription ?? "Unknown error")")
                completion([], error)
                return
            }
            
            print("Found \(workouts.count) workouts in HealthKit")
            
            let dispatchGroup = DispatchGroup()
            var detailedWorkouts: [DetailedWorkout] = []
            
            for workout in workouts {
                dispatchGroup.enter()
                self.fetchAdditionalData(for: workout) { detailedWorkout in
                    if let detailedWorkout = detailedWorkout {
                        detailedWorkouts.append(detailedWorkout)
                    }
                    dispatchGroup.leave()
                }
            }
            
            dispatchGroup.notify(queue: .main) {
                print("Processed \(detailedWorkouts.count) workouts")
                DispatchQueue.main.async {
                    self.workouts = detailedWorkouts
                    self.batchRecordWorkoutsInDatabase(detailedWorkouts)
                    self.updateLastSyncDate()
                }
                completion(detailedWorkouts, nil)
            }
        }
        
        healthStore.execute(query)
    }
    
    private func batchRecordWorkoutsInDatabase(_ workouts: [DetailedWorkout]) {
        guard let userId = getCurrentUserId() else {
            print("Error: Unable to get current user ID")
            return
        }

        let batchSize = 500 // Firestore's limit on batch write size
        var batch = db.batch()
        var operationCount = 0

        for workout in workouts {
            let calendar = Calendar.current
            let workoutYear = calendar.component(.year, from: workout.date)

            // Filtering for valid workouts based on year and duration
            guard workoutYear >= 2023, workout.duration > 60 else {
                continue
            }

            // Prepare workout data with all the details
            var workoutData: [String: Any] = [
                "userId": userId,
                "id": workout.id.uuidString,
                "type": workout.type.rawValue, // Activity type (running, cycling, etc.)
                "distance": workout.distance,
                "duration": workout.duration,
                "calories": workout.calories,
                "date": Timestamp(date: workout.date),
                "intensity": workout.intensity.rawValue, // Workout intensity (low, moderate, high)
                "sourceName": workout.sourceName ?? NSNull(),
                "routeImageUrl": workout.routeImageUrl ?? NSNull()
            ]

            // Include optional workout details if available
            if let averageHeartRate = workout.averageHeartRate {
                workoutData["averageHeartRate"] = averageHeartRate
            }
            if let maxHeartRate = workout.maxHeartRate {
                workoutData["maxHeartRate"] = maxHeartRate
            }
            if let stepsCount = workout.stepsCount {
                workoutData["stepsCount"] = Int(stepsCount)
            }
            if let pace = workout.pace {
                workoutData["pace"] = pace
            }
            if let averageCadence = workout.averageCadence {
                workoutData["averageCadence"] = averageCadence
            }
            if let weather = workout.weather {
                workoutData["weather"] = weather
            }

            // Write to the top-level "workouts" collection with the workout ID
            let workoutDocRef = db.collection("workouts").document(workout.id.uuidString)

            batch.setData(workoutData, forDocument: workoutDocRef, merge: true)
            operationCount += 1

            // Commit the batch if the limit is reached
            if operationCount == batchSize {
                commitBatch(batch)
                batch = db.batch()
                operationCount = 0
            }
        }

        // Commit any remaining writes
        if operationCount > 0 {
            commitBatch(batch)
        }
    }

    
    
    
    private func fetchAdditionalData(for workout: HKWorkout, completion: @escaping (DetailedWorkout?) -> Void) {
        let heartRateType = HKObjectType.quantityType(forIdentifier: .heartRate)!
        let stepsType = HKObjectType.quantityType(forIdentifier: .stepCount)!
        let cadenceType = HKQuantityType.quantityType(forIdentifier: .runningStrideLength)!
        
        let predicate = HKQuery.predicateForSamples(withStart: workout.startDate, end: workout.endDate, options: .strictStartDate)
        
        let heartRateQuery = HKStatisticsQuery(quantityType: heartRateType, quantitySamplePredicate: predicate, options: [.discreteAverage, .discreteMax]) { _, statistics, _ in
            let avgHeartRate = statistics?.averageQuantity()?.doubleValue(for: HKUnit(from: "count/min"))
            let maxHeartRate = statistics?.maximumQuantity()?.doubleValue(for: HKUnit(from: "count/min"))
            
            let stepsQuery = HKStatisticsQuery(quantityType: stepsType, quantitySamplePredicate: predicate, options: .cumulativeSum) { _, stepsStats, _ in
                let stepsCount = stepsStats?.sumQuantity()?.doubleValue(for: HKUnit.count())
                
                let cadenceQuery = HKStatisticsQuery(quantityType: cadenceType, quantitySamplePredicate: predicate, options: .discreteAverage) { _, cadenceStats, _ in
                       let averageCadence = cadenceStats?.averageQuantity()?.doubleValue(for: HKUnit(from: "count/min"))
                       
                       let pace = workout.totalDistance != nil && workout.totalDistance!.doubleValue(for: .meter()) > 0
                           ? workout.duration / (workout.totalDistance!.doubleValue(for: .meter()) / 1000)
                           : nil
                       
                       var detailedWorkout = DetailedWorkout(
                           id: workout.uuid,
                           type: workout.workoutActivityType,
                           distance: workout.totalDistance?.doubleValue(for: .meter()) ?? 0,
                           duration: workout.duration,
                           calories: workout.totalEnergyBurned?.doubleValue(for: .kilocalorie()) ?? 0,
                           date: workout.startDate,
                           averageHeartRate: avgHeartRate,
                           maxHeartRate: maxHeartRate,
                           stepsCount: stepsCount,
                           pace: pace,
                           routeImageUrl: nil,
                           intensity: self.calculateIntensity(avgHeartRate: avgHeartRate, maxHeartRate: maxHeartRate),
                           averageCadence: averageCadence,
                           weather: nil,
                           sourceName: workout.sourceRevision.source.name,
                           userFirstName: "",  // Add this line
                           userLastName: "",   // Add this line
                           userProfilePictureUrl: nil  // Add this line
                       )
                       
                       self.generateStaticMapUrl(for: workout) { url in
                           var detailedWorkout = DetailedWorkout(
                               id: workout.uuid,
                               type: workout.workoutActivityType,
                               distance: workout.totalDistance?.doubleValue(for: .meter()) ?? 0,
                               duration: workout.duration,
                               calories: workout.totalEnergyBurned?.doubleValue(for: .kilocalorie()) ?? 0,
                               date: workout.startDate,
                               averageHeartRate: avgHeartRate,
                               maxHeartRate: maxHeartRate,
                               stepsCount: stepsCount,
                               pace: pace,
                               routeImageUrl: url,  // Pass the URL here
                               intensity: self.calculateIntensity(avgHeartRate: avgHeartRate, maxHeartRate: maxHeartRate),
                               averageCadence: averageCadence,
                               weather: nil,
                               sourceName: workout.sourceRevision.source.name,
                               userFirstName: "",  // Add this line
                               userLastName: "",   // Add this line
                               userProfilePictureUrl: nil  // Add this line
                           )
                           completion(detailedWorkout)
                       }
                }
                self.healthStore.execute(cadenceQuery)
            }
            self.healthStore.execute(stepsQuery)
        }
        healthStore.execute(heartRateQuery)
    }
        
        private func fetchRoute(for workout: HKWorkout, completion: @escaping ([CLLocationCoordinate2D]?) -> Void) {
            let routeType = HKSeriesType.workoutRoute()
            
            let routeQuery = HKAnchoredObjectQuery(type: routeType, predicate: HKQuery.predicateForObjects(from: workout), anchor: nil, limit: HKObjectQueryNoLimit) { (query, samples, deletedObjects, anchor, error) in
                guard let routeSamples = samples as? [HKWorkoutRoute], let routeSample = routeSamples.first else {
                    completion(nil)
                    return
                }
                
                var allLocations: [CLLocationCoordinate2D] = []
                let routeQuery = HKWorkoutRouteQuery(route: routeSample) { (query, locations, done, error) in
                    guard let locations = locations else {
                        if done {
                            completion(allLocations.isEmpty ? nil : allLocations)
                        }
                        return
                    }
                    
                    allLocations.append(contentsOf: locations.map { $0.coordinate })
                    
                    if done {
                        completion(allLocations)
                    }
                }
                
                self.healthStore.execute(routeQuery)
            }
            
            healthStore.execute(routeQuery)
        }
        
        private func calculateIntensity(avgHeartRate: Double?, maxHeartRate: Double?) -> WorkoutIntensity {
            guard let avg = avgHeartRate else { return .moderate }
            if avg < 100 {
                return .low
            } else if avg < 140 {
                return .moderate
            } else {
                return .high
            }
        }
        
//    private func simplifyRoute(_ route: [CLLocationCoordinate2D]?) -> [CLLocationCoordinate2D]? {
//        guard let route = route else { return nil }
//
//        let maxPoints = 100 // Limit the maximum number of points to reduce URL size
//        let strideValue = max(route.count / maxPoints, 1) // Adjust stride based on total points
//
//        return stride(from: 0, to: route.count, by: strideValue).map { route[$0] }
//    }

        
    private func generateStaticMapUrl(for workout: HKWorkout, completion: @escaping (String?) -> Void) {
        fetchRoute(for: workout) { route in
            guard let route = route, !route.isEmpty else {
                print("Debug: Route is empty or nil")
                completion(nil)
                return
            }
            
            let simplifiedRoute = self.simplifyRoute(route)
            let path = simplifiedRoute.map { "\($0.latitude),\($0.longitude)" }.joined(separator: "|")
            let baseUrl = "https://maps.googleapis.com/maps/api/staticmap"
            let params = [
                "size": "400x400",
                "path": "color:0x0000ff|weight:5|\(path)",
                "key": "AIzaSyCsJrIQR_ESMJGkzP-sHDbTK7mG6L2YyHM"
            ]
            
            let queryItems = params.map { URLQueryItem(name: $0.key, value: $0.value) }
            var urlComps = URLComponents(string: baseUrl)!
            urlComps.queryItems = queryItems
            
            guard let url = urlComps.url?.absoluteString else {
                print("Debug: Failed to construct URL")
                completion(nil)
                return
            }
            
            print("Debug: Generated URL: \(url)")
            completion(url)
        }
    }

    private func simplifyRoute(_ route: [CLLocationCoordinate2D]) -> [CLLocationCoordinate2D] {
        let maxPoints = 100 // Limit the maximum number of points to reduce URL size
        let strideValue = max(route.count / maxPoints, 1) // Adjust stride based on total points
        return stride(from: 0, to: route.count, by: strideValue).map { route[$0] }
    }
        
        private func commitBatch(_ batch: WriteBatch) {
            batch.commit { error in
                if let error = error {
                    print("Error committing batch: \(error)")
                } else {
                    print("Batch write successful")
                }
            }
        }
        
        
        private func updateLastSyncDate() {
            let newSyncDate = Date()
            UserDefaults.standard.set(newSyncDate, forKey: "lastWorkoutSyncDate")
            self.lastSyncDate = newSyncDate
        }
    
    func enableBackgroundDelivery() {
        let workoutType = HKObjectType.workoutType()
        
        healthStore.enableBackgroundDelivery(for: workoutType, frequency: .immediate) { (success, error) in
            if success {
                print("Background delivery enabled for workouts")
            } else if let error = error {
                print("Failed to enable background delivery: \(error.localizedDescription)")
            }
        }
    }
    
    func handleBackgroundDelivery(for samples: [HKSample]) {
        for case let workout as HKWorkout in samples {
            fetchAdditionalData(for: workout) { detailedWorkout in
                if let detailedWorkout = detailedWorkout {
                    self.batchRecordWorkoutsInDatabase([detailedWorkout]) // Batch process single workout
                    DispatchQueue.main.async {
                        self.workouts.append(detailedWorkout)
                    }
                }
            }
        }
    }

    func fetchWorkoutsFromFirestore(completion: @escaping ([DetailedWorkout], Error?) -> Void) {
        guard let userId = getCurrentUserId() else {
            completion([], NSError(domain: "HealthKitManager", code: 0, userInfo: [NSLocalizedDescriptionKey: "Unable to get current user ID"]))
            return
        }

        db.collection("users").document(userId).collection("workouts").getDocuments { (querySnapshot, error) in
            if let error = error {
                completion([], error)
                return
            }

            let workouts = querySnapshot?.documents.compactMap { document -> DetailedWorkout? in
                    let data = document.data()
                    return DetailedWorkout(
                        id: UUID(uuidString: data["id"] as? String ?? "") ?? UUID(),
                        type: HKWorkoutActivityType(rawValue: data["type"] as? UInt ?? 0) ?? .other,
                        distance: data["distance"] as? Double ?? 0,
                        duration: data["duration"] as? TimeInterval ?? 0,
                        calories: data["calories"] as? Double ?? 0,
                        date: (data["date"] as? Timestamp)?.dateValue() ?? Date(),
                        averageHeartRate: data["averageHeartRate"] as? Double,
                        maxHeartRate: data["maxHeartRate"] as? Double,
                        stepsCount: Double(data["stepsCount"] as? Int ?? 0),
                        pace: data["pace"] as? TimeInterval,
                        routeImageUrl: data["routeImageUrl"] as? String,
                        intensity: WorkoutIntensity(rawValue: data["intensity"] as? String ?? "") ?? .moderate,
                        averageCadence: data["averageCadence"] as? Double,
                        weather: data["weather"] as? String,
                        sourceName: data["sourceName"] as? String,
                        userFirstName: data["userFirstName"] as? String ?? "", // Add this line
                        userLastName: data["userLastName"] as? String ?? "", // Add this line
                        userProfilePictureUrl: data["userProfilePictureUrl"] as? String // Add this line
                    )
                } ?? []


            DispatchQueue.main.async {
                self.workouts = workouts
            }
            completion(workouts, nil)
        }
    }

    
}



// Extension to provide a string representation of HKWorkoutActivityType
extension HKWorkoutActivityType {
    static func workoutTypeString(for type: HKWorkoutActivityType) -> String {
        switch type {
        case .running:
            return "Running"
        case .cycling:
            return "Cycling"
        // Add more cases as needed
        default:
            return "Other"
        }
    }
}
    
    
