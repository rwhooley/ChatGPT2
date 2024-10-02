//
//  PerformanceView.swift
//  ChatGPT2
//
//  Created by Ryan Whooley on 8/25/24.
//

import SwiftUI
import Charts
import FirebaseFirestore
import FirebaseAuth
import MapKit
import HealthKit

extension Calendar {
    func startOfMonth(for date: Date) -> Date {
        let components = dateComponents([.year, .month], from: date)
        return self.date(from: components)!
    }
}

struct PerformanceView: View {
    @EnvironmentObject var healthKitManager: HealthKitManager
    @State private var currentMonthWorkouts: [DetailedWorkout] = []
    @State private var expandedMonths: Set<String> = []
    @State private var errorMessage: String?
    
    var body: some View {
        NavigationView {
            ScrollView {
                VStack(spacing: 20) {
                    content
                }
                .padding()
            }
            .onAppear(perform: fetchCurrentMonthWorkouts)
        }
    }
    
    @ViewBuilder
    private var content: some View {
        if let errorMessage = errorMessage {
            Text(errorMessage)
                .foregroundColor(.red)
                .padding()
        } else {
            VStack {
//                Text("Workouts fetched: \(currentMonthWorkouts.count)")
//                    .font(.headline)
//                    .foregroundColor(.blue)

                if currentMonthWorkouts.isEmpty {
                    Text("No qualifying workouts found")
                        .foregroundColor(.gray)
                        .padding()
                } else {
                    CurrentMonthModule(workouts: currentMonthWorkouts)
                    PastMonthsModule(workouts: currentMonthWorkouts, expandedMonths: $expandedMonths)
                }
            }
        }
    }

    private func fetchCurrentMonthWorkouts() {
        guard let userId = healthKitManager.getCurrentUserId() else {
            self.errorMessage = "Error: Unable to get current user ID."
            return
        }

        let calendar = Calendar.current
        let now = Date()
        let startOfMonth = calendar.startOfMonth(for: now)
        let endOfMonth = calendar.date(byAdding: DateComponents(month: 1, day: -1), to: startOfMonth)!

        print("Querying Firestore from \(startOfMonth) to \(endOfMonth)...")

        // Querying from the top-level 'workouts' collection and filtering by 'userId'
        healthKitManager.db.collection("workouts")
            .whereField("userId", isEqualTo: userId)
//            .whereField("date", isGreaterThanOrEqualTo: Timestamp(date: startOfMonth))
//            .whereField("date", isLessThanOrEqualTo: Timestamp(date: endOfMonth))
            .getDocuments { (snapshot, error) in
                if let error = error {
                    self.errorMessage = "Failed to load workouts: \(error.localizedDescription)"
                } else if let documents = snapshot?.documents {
                    print("Found \(documents.count) documents in Firestore")

                    self.currentMonthWorkouts = documents.compactMap { document -> DetailedWorkout? in
                        let data = document.data()
                        
                        // Ensuring the UUID is valid
                        guard let id = UUID(uuidString: data["id"] as? String ?? "") else {
                            print("Invalid UUID, skipping workout")
                            return nil
                        }
                        
                        // Determine workout type
                        let workoutType: HKWorkoutActivityType
                        if let typeValue = data["type"] as? UInt {
                            workoutType = HKWorkoutActivityType(rawValue: typeValue) ?? .other
                        } else {
                            workoutType = .other
                        }

                        // Constructing the DetailedWorkout object with all its attributes
                        let workout = DetailedWorkout(
                            id: id,
                            type: workoutType,
                            distance: data["distance"] as? Double ?? 0.0,
                            duration: data["duration"] as? TimeInterval ?? 0.0,
                            calories: data["calories"] as? Double ?? 0.0,
                            date: (data["date"] as? Timestamp)?.dateValue() ?? Date(),
                            averageHeartRate: data["averageHeartRate"] as? Double,
                            maxHeartRate: data["maxHeartRate"] as? Double,
                            stepsCount: data["stepsCount"] as? Double,
                            pace: data["pace"] as? TimeInterval,
                            routeImageUrl: data["routeImageUrl"] as? String,
                            intensity: WorkoutIntensity(rawValue: data["intensity"] as? String ?? "") ?? .moderate,
                            averageCadence: data["averageCadence"] as? Double,
                            weather: data["weather"] as? String,
                            sourceName: data["sourceName"] as? String,
                            userFirstName: "", // Add this line
                            userLastName: "", // Add this line
                            userProfilePictureUrl: nil // Add this line
                        )

                        // Apply your workout qualification logic
                        let isQualifying = self.isQualifyingWorkout(workout)
                        if !isQualifying {
                            print("Non-qualifying workout: \(workout)")
                        }

                        return isQualifying ? workout : nil
                    }

                    print("Fetched \(self.currentMonthWorkouts.count) qualifying workouts")
                }
            }
    }

    
    private func isQualifyingWorkout(_ workout: DetailedWorkout) -> Bool {
        let distanceInMiles = workout.distance / 1609.34 // Convert meters to miles
        let paceInMinutesPerMile = (workout.pace ?? 0) / 60 // Convert seconds per km to minutes per mile

        switch workout.type {
        case .running:
            return distanceInMiles >= 2 && paceInMinutesPerMile <= 12 // 2 miles and pace better than 12 min/mile
        case .cycling:
            return distanceInMiles >= 6 && paceInMinutesPerMile <= 4 // 6 miles and pace better than 4 min/mile
        default:
            return false
        }
    }
}

struct CalendarView: View {
    let daysInMonth: Int
    let firstDayOfMonth: Int
    let workouts: [DetailedWorkout]

    var body: some View {
        VStack {
            // Day of the week headers
            HStack {
                ForEach(["S", "M", "T", "W", "T", "F", "S"], id: \.self) { day in
                    Text(day)
                        .fontWeight(.bold)
                        .frame(maxWidth: .infinity)
                }
            }

            LazyVGrid(columns: Array(repeating: GridItem(.flexible()), count: 7), spacing: 4) {
                // Add empty spaces for days before the first day of the month
                ForEach(0..<firstDayOfMonth, id: \.self) { _ in
                    Rectangle()
                        .fill(Color.clear)
                        .frame(height: 20)
                }

                // Render days of the month
                ForEach(1...daysInMonth, id: \.self) { day in
                    ZStack {
                        let intensity = workoutIntensity(for: day, in: workouts)
                        Rectangle()
                            .fill(intensityColor(for: intensity))
                            .frame(height: 20)
                            .cornerRadius(4)

                        Text("\(day)")
                            .font(.caption2)
                            .foregroundColor(.white)
                    }
                }
            }
        }
        .padding(.horizontal)
    }

    // Helper Functions
    private func colorForDay(_ day: Int) -> Color {
            let calendar = Calendar.current
            let hasWorkout = workouts.contains { calendar.component(.day, from: $0.date) == day }
            return hasWorkout ? .green : Color.gray.opacity(0.3)
        
        }
    }
    
    private func workoutIntensity(for day: Int, in workouts: [DetailedWorkout]) -> Double {
        let calendar = Calendar.current
        let dailyWorkouts = workouts.filter {
            calendar.component(.day, from: $0.date) == day
        }
        let totalDistance = dailyWorkouts.reduce(0) { $0 + $1.distance }
        return totalDistance
    }

    private func intensityColor(for intensity: Double) -> Color {
        let maxIntensity: Double = 10000 // Adjust this based on expected maximum distance
        let normalizedIntensity = min(intensity / maxIntensity, 1.0)
        return Color.blue.opacity(normalizedIntensity)
    }


struct CurrentMonthModule: View {
    let workouts: [DetailedWorkout]

    var body: some View {
        VStack(alignment: .leading, spacing: 10) {
            Text("Workouts This Month")
                .font(.title2)
                .fontWeight(.bold)

            CalendarView(daysInMonth: daysInCurrentMonth, firstDayOfMonth: firstDayOfCurrentMonth, workouts: filteredWorkoutsForCurrentMonth)
            
            HStack {
                StatView(title: "Qualifying Workouts", value: "\(filteredWorkoutsForCurrentMonth.count)")
                StatView(title: "Total Miles", value: String(format: "%.1f", totalMilesForCurrentMonth))
                StatView(title: "Avg Miles Per Workout", value: String(format: "%.1f", averageMilesForCurrentMonth))
            }
        }
        .padding()
        .background(Color.gray.opacity(0.1))
        .cornerRadius(10)
    }
    
    // Filter workouts that took place in the current month
    private var filteredWorkoutsForCurrentMonth: [DetailedWorkout] {
        let calendar = Calendar.current
        return workouts.filter { workout in
            let workoutMonth = calendar.component(.month, from: workout.date)
            let workoutYear = calendar.component(.year, from: workout.date)
            let currentMonth = calendar.component(.month, from: Date())
            let currentYear = calendar.component(.year, from: Date())
            return workoutMonth == currentMonth && workoutYear == currentYear
        }
    }

    private var daysInCurrentMonth: Int {
        let calendar = Calendar.current
        let range = calendar.range(of: .day, in: .month, for: Date())
        return range?.count ?? 30
    }

    private var firstDayOfCurrentMonth: Int {
        let calendar = Calendar.current
        let startOfMonth = calendar.startOfMonth(for: Date())
        return calendar.component(.weekday, from: startOfMonth) - 1
    }

    private var totalMilesForCurrentMonth: Double {
        filteredWorkoutsForCurrentMonth.reduce(0) { $0 + $1.distance / 1609.34 }
    }
    
    private var averageMilesForCurrentMonth: Double {
        filteredWorkoutsForCurrentMonth.isEmpty ? 0 : totalMilesForCurrentMonth / Double(filteredWorkoutsForCurrentMonth.count)
    }
}


struct PastMonthsModule: View {
    let workouts: [DetailedWorkout]
    @Binding var expandedMonths: Set<String>

    var body: some View {
        VStack(alignment: .leading, spacing: 10) {
            Text("Workout Log")
                .font(.title2)
                .fontWeight(.bold)
            
            ForEach(workouts.sorted(by: { $0.date > $1.date }), id: \.id) { workout in
                WorkoutRow(workout: workout)
            }
        }
    }
}
//    private var sortedMonths: [String] {
//        workoutsByMonth.keys.sorted(by: { formatDateToDate($0) > formatDateToDate($1) })
//    }

    private func daysInMonth(for month: String) -> Int {
        let formatter = DateFormatter()
        formatter.dateFormat = "MMMM yyyy"
        guard let date = formatter.date(from: month) else { return 30 }
        let calendar = Calendar.current
        let range = calendar.range(of: .day, in: .month, for: date)
        return range?.count ?? 30
    }

    private func firstDayOfMonth(for month: String) -> Int {
        let formatter = DateFormatter()
        formatter.dateFormat = "MMMM yyyy"
        guard let date = formatter.date(from: month) else { return 0 }
        let calendar = Calendar.current
        let startOfMonth = calendar.startOfMonth(for: date)
        return calendar.component(.weekday, from: startOfMonth) - 1
    }

    private func formatDateToDate(_ month: String) -> Date {
        let formatter = DateFormatter()
        formatter.dateFormat = "MMMM yyyy"
        return formatter.date(from: month) ?? Date.distantPast
    }

//    private func monthHeader(for month: String) -> some View {
//        let workouts = workoutsByMonth[month] ?? []
//        let totalWorkouts = workouts.count
//        let antelopeWorkouts = workouts.filter { isAntelopeWorkout($0) }.count
//
//        return HStack {
//            Text(month)
//            Spacer()
//            VStack(alignment: .trailing) {
//                Text("\(totalWorkouts) total")
//                Text("\(antelopeWorkouts) Antelope")
//                    .font(.caption)
//                    .foregroundColor(.secondary)
//            }
//        }
//        .contentShape(Rectangle())
//        .onTapGesture {
//            toggleMonth(month)
//        }
//    }

    private func isAntelopeWorkout(_ workout: DetailedWorkout) -> Bool {
        switch workout.type {
        case .running:
            return workout.distance >= 3218.69 // 2 miles
        case .cycling:
            return workout.distance >= 9656.06 // 6 miles
        default:
            return false
        }
    }




struct StatView: View {
    let title: String
    let value: String

    var body: some View {
        VStack {
            Text(title)
                .font(.caption)
                .foregroundColor(.secondary)
            Text(value)
                .font(.headline)
        }
        .frame(maxWidth: .infinity)
    }
}

struct WorkoutRow: View {
    let workout: DetailedWorkout

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack {
                // Profile Picture
                if let profilePictureUrl = workout.userProfilePictureUrl,
                   let url = URL(string: profilePictureUrl) {
                    AsyncImage(url: url) { image in
                        image
                            .resizable()
                            .aspectRatio(contentMode: .fill)
                            .frame(width: 50, height: 50)
                            .clipShape(Circle())
                    } placeholder: {
                        ProgressView()
                            .frame(width: 50, height: 50)
                    }
                } else {
                    Image(systemName: "person.circle.fill")
                        .resizable()
                        .frame(width: 50, height: 50)
                        .foregroundColor(.gray)
                }
                
                VStack(alignment: .leading) {
                    Text("\(workout.userFirstName) \(workout.userLastName)")
                        .font(.headline)
                        .foregroundColor(.primary)
                    Text(workoutTypeName(workout.type))
                        .font(.subheadline)
                        .foregroundColor(.secondary)
                }
                
                Spacer()
                
                Text(formatDate(workout.date))
                    .font(.caption)
                    .foregroundColor(.secondary)
            }
            
            // Workout Details
            VStack(alignment: .leading, spacing: 4) {
                HStack {
                    Text("Distance:")
                        .fontWeight(.bold)
                    Text("\(String(format: "%.2f", workout.distance / 1609.34)) miles")
                        .foregroundColor(.blue)
                }
                
                HStack {
                    Text("Duration:")
                        .fontWeight(.bold)
                    Text(formatDuration(workout.duration))
                        .foregroundColor(.blue)
                }
                
                if let pace = workout.pace, workout.distance > 0 {
                    HStack {
                        Text("Average Pace:")
                            .fontWeight(.bold)
                        Text(formatPace(workout.duration, distance: workout.distance))
                            .foregroundColor(.blue)
                    }
                }

             
                    HStack {
                        Text("Calories Burned:")
                            .fontWeight(.bold)
                        Text("\(Int(workout.calories)) kcal")
                            .foregroundColor(.blue)
                    }
                

                if let steps = workout.stepsCount {
                    HStack {
                        Text("Steps:")
                            .fontWeight(.bold)
                        Text("\(Int(steps)) steps")
                            .foregroundColor(.blue)
                    }
                }
                
                if let avgHeartRate = workout.averageHeartRate {
                    HStack {
                        Text("Avg Heart Rate:")
                            .fontWeight(.bold)
                        Text("\(Int(avgHeartRate)) bpm")
                            .foregroundColor(.blue)
                    }
                }
                
                if let maxHeartRate = workout.maxHeartRate {
                    HStack {
                        Text("Max Heart Rate:")
                            .fontWeight(.bold)
                        Text("\(Int(maxHeartRate)) bpm")
                            .foregroundColor(.blue)
                    }
                }

                if let weather = workout.weather {
                    HStack {
                        Text("Weather:")
                            .fontWeight(.bold)
                        Text(weather)
                            .foregroundColor(.blue)
                    }
                }
            }

            // Workout Route Image
            if let routeImageUrl = workout.routeImageUrl {
                AsyncImage(url: URL(string: routeImageUrl)) { image in
                    image
                        .resizable()
                        .aspectRatio(contentMode: .fit)
                        .frame(height: 200)
                        .cornerRadius(10)
                } placeholder: {
                    ProgressView()
                        .frame(height: 200)
                }
            } else {
                Text("No route image available")
                    .font(.caption)
                    .foregroundColor(.gray)
            }
        }
        .padding()
        .background(Color.gray.opacity(0.1))
        .cornerRadius(10)
        .shadow(color: Color.black.opacity(0.1), radius: 3, x: 0, y: 2)
        .padding(.vertical, 5)
    }
}


    private func workoutTypeName(_ type: HKWorkoutActivityType) -> String {
        switch type {
        case .running:
            return "Running"
        case .cycling:
            return "Cycling"
        default:
            return "Other"
        }
    }
    
    private func formatDate(_ date: Date) -> String {
        let formatter = DateFormatter()
        formatter.dateStyle = .medium
        formatter.timeStyle = .short
        return formatter.string(from: date)
    }

    private func formatDuration(_ duration: TimeInterval) -> String {
        let formatter = DateComponentsFormatter()
        formatter.allowedUnits = [.hour, .minute, .second]
        formatter.unitsStyle = .abbreviated
        return formatter.string(from: duration) ?? ""
    }

    private func formatPace(_ pace: TimeInterval, distance: Double) -> String {
        guard pace.isFinite && !pace.isNaN && pace > 0, distance > 0 else {
            return "N/A"
        }

        // Convert distance from meters to miles
        let distanceInMiles = distance / 1609.34

        // Calculate pace in minutes per mile
        let paceInMinutesPerMile = pace / distanceInMiles

        let minutes = Int(paceInMinutesPerMile) / 60
        let seconds = Int(paceInMinutesPerMile) % 60
        return String(format: "%d:%02d /mi", minutes, seconds)
    }





    private func metersToMiles(_ meters: Double) -> Double {
            return meters / 1609.34
        }
    
//    private func formatPace(_ pace: TimeInterval) -> String {
//        guard pace.isFinite && !pace.isNaN && pace > 0 else {
//            return "N/A"
//        }
//        
//        // Convert pace from km per minute to miles per minute
//        let paceInMiles = pace * 1.60934 // Multiply by the conversion factor to get miles per minute
//        
//        let minutes = Int(paceInMiles) / 60
//        let seconds = Int(paceInMiles) % 60
//        return String(format: "%d:%02d /mi", minutes, seconds) // Updated to display "/mi" instead of "/km"
//    }


struct MapView: UIViewRepresentable {
    let coordinates: [CLLocationCoordinate2D]

    func makeUIView(context: Context) -> MKMapView {
        let mapView = MKMapView()
        mapView.delegate = context.coordinator
        return mapView
    }

    func updateUIView(_ uiView: MKMapView, context: Context) {
        let polyline = MKPolyline(coordinates: coordinates, count: coordinates.count)
        uiView.removeOverlays(uiView.overlays)
        uiView.addOverlay(polyline)
        uiView.setVisibleMapRect(polyline.boundingMapRect, edgePadding: UIEdgeInsets(top: 20, left: 20, bottom: 20, right: 20), animated: true)
    }

    func makeCoordinator() -> Coordinator {
        Coordinator(self)
    }

    class Coordinator: NSObject, MKMapViewDelegate {
        var parent: MapView

        init(_ parent: MapView) {
            self.parent = parent
        }

        func mapView(_ mapView: MKMapView, rendererFor overlay: MKOverlay) -> MKOverlayRenderer {
            if let polyline = overlay as? MKPolyline {
                let renderer = MKPolylineRenderer(polyline: polyline)
                renderer.strokeColor = .blue
                renderer.lineWidth = 3
                return renderer
            }
            return MKOverlayRenderer()
        }
    }
}

enum WorkoutType: String {
    case running = "Running"
    case cycling = "Cycling"
    case other = "Other"
}

extension WorkoutType {
    static func name(for type: WorkoutType) -> String {
        switch type {
        case .running:
            return "Running"
        case .cycling:
            return "Cycling"
        default:
            return "Other"
        }
    }
}


#Preview {
    PerformanceView()
        .environmentObject(HealthKitManager())
}
