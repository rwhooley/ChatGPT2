//
//  WorkoutSyncManager.swift
//  ChatGPT2
//
//  Created by Ryan Whooley on 8/27/24.
//

import Foundation
import Combine

class WorkoutSyncManager: ObservableObject {
    private let syncJob: FirebaseWorkoutSyncJob
    @Published var isSyncing: Bool = false
    
    init() {
        let healthKitManager = HealthKitManager.shared // Assuming you have a shared instance
        guard let userID = UserDefaults.standard.string(forKey: "userID") else {
            fatalError("User ID not found")
        }
        self.syncJob = FirebaseWorkoutSyncJob(healthKitManager: healthKitManager, userID: userID)
    }
    
    func syncWorkouts() {
        isSyncing = true
        syncJob.syncNewWorkouts { [weak self] in
            DispatchQueue.main.async {
                self?.isSyncing = false
            }
        }
    }
}
