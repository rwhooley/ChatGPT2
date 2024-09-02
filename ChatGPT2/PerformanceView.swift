//
//  PerformanceView.swift
//  ChatGPT2
//
//  Created by Ryan Whooley on 8/25/24.
//

import SwiftUI
import HealthKit
import Charts

extension Calendar {
    func startOfMonth(for date: Date) -> Date {
        let components = dateComponents([.year, .month], from: date)
        return self.date(from: components)!
    }
}

struct PerformanceView: View {
    @EnvironmentObject private var healthKitManager: HealthKitManager
    @State private var workoutsByMonth: [String: [DetailedWorkout]] = [:]
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
            .navigationTitle("Performance")
            .onAppear(perform: fetchWorkouts)
        }
    }

    @ViewBuilder
    private var content: some View {
        if let errorMessage = errorMessage {
            Text(errorMessage)
                .foregroundColor(.red)
                .padding()
        } else if workoutsByMonth.isEmpty {
            Text("No workouts found")
                .padding()
        } else {
            ThisMonthModule(workouts: currentMonthWorkouts)
            LastMonthModule(workouts: lastMonthWorkouts)
            ThisYearModule(workouts: lastTwelveMonthsWorkouts)
            PastMonthsModule(workoutsByMonth: workoutsByMonth, expandedMonths: $expandedMonths)
        }
    }

    private var currentMonthWorkouts: [DetailedWorkout] {
        let currentMonth = formatMonth(date: Date())
        return workoutsByMonth[currentMonth] ?? []
    }

    private var lastMonthWorkouts: [DetailedWorkout] {
        let calendar = Calendar.current
        guard let lastMonth = calendar.date(byAdding: .month, value: -1, to: Date()) else { return [] }
        let lastMonthString = formatMonth(date: lastMonth)
        return workoutsByMonth[lastMonthString] ?? []
    }

    private var lastTwelveMonthsWorkouts: [DetailedWorkout] {
        let calendar = Calendar.current
        guard let twelveMonthsAgo = calendar.date(byAdding: .month, value: -12, to: Date()) else { return [] }
        return workoutsByMonth.values.flatMap { $0 }.filter { $0.date >= twelveMonthsAgo }
    }

    private func fetchWorkouts() {
        healthKitManager.fetchAllDetailedWorkouts { fetchedWorkouts, error in
            if let error = error {
                self.errorMessage = "Failed to load workouts: \(error.localizedDescription)"
            } else if fetchedWorkouts.isEmpty {
                self.errorMessage = "No workouts found in HealthKit."
            } else {
                // Filter out workouts less than 5 minutes
                let filteredWorkouts = fetchedWorkouts.filter { $0.duration >= 300 }
                
                // Group workouts by month
                self.workoutsByMonth = Dictionary(grouping: filteredWorkouts) { workout in
                    formatMonth(date: workout.date)
                }
            }
        }
    }

    private func formatMonth(date: Date) -> String {
        let formatter = DateFormatter()
        formatter.dateFormat = "MMMM yyyy"
        return formatter.string(from: date)
    }
}

struct HeatMapGrid: View {
    let daysInMonth: Int
    let firstDayOfMonth: Int
    let workouts: [DetailedWorkout]

    var body: some View {
        let dailyWorkouts = groupWorkoutsByDay()
        
        VStack {
            // Day of the week headers
            HStack {
                ForEach(["S", "M", "T", "W", "T", "F", "S"], id: \.self) { day in
                    Text(day)
                        .fontWeight(.bold)
                        .frame(maxWidth: .infinity)
                }
            }
            
            // Grid with days and workout intensity
            LazyVGrid(columns: Array(repeating: GridItem(.flexible()), count: 7), spacing: 4) {
                // Add empty spaces for the first week if the month doesn't start on Sunday
                ForEach(0..<firstDayOfMonth, id: \.self) { _ in
                    Rectangle()
                        .fill(Color.clear)
                        .frame(height: 20)
                }

                ForEach(1...daysInMonth, id: \.self) { day in
                    let intensity = workoutIntensity(for: day, in: dailyWorkouts)
                    ZStack {
                        Rectangle()
                            .fill(intensityColor(for: intensity))
                            .frame(height: 20)
                            .cornerRadius(4)
                        
                        Text("\(day)") // Display the day number
                            .font(.caption2)
                            .foregroundColor(.white)
                    }
                }
            }
        }
        .padding(.horizontal)
    }
    
    private func groupWorkoutsByDay() -> [Int: [DetailedWorkout]] {
        let calendar = Calendar.current
        return Dictionary(grouping: workouts) { workout in
            calendar.component(.day, from: workout.date)
        }
    }
    
    private func workoutIntensity(for day: Int, in dailyWorkouts: [Int: [DetailedWorkout]]) -> Double {
        guard let workouts = dailyWorkouts[day] else { return 0 }
        let totalDistance = workouts.reduce(0) { $0 + $1.distance }
        return totalDistance
    }
    
    private func intensityColor(for intensity: Double) -> Color {
        let maxIntensity: Double = 10000 // Adjust this based on expected maximum distance
        let normalizedIntensity = min(intensity / maxIntensity, 1.0)
        return Color.blue.opacity(normalizedIntensity)
    }
}

struct ThisMonthModule: View {
    let workouts: [DetailedWorkout]

    var body: some View {
        VStack(alignment: .leading, spacing: 10) {
            Text("This Month")
                .font(.title2)
                .fontWeight(.bold)

            HeatMapGrid(daysInMonth: daysInCurrentMonth, firstDayOfMonth: firstDayOfCurrentMonth, workouts: antelopeWorkouts)
            
            HStack {
                StatView(title: "Antelope Workouts", value: "\(antelopeWorkouts.count)") // Only counting Antelope workouts
                StatView(title: "Total Miles", value: String(format: "%.1f", totalMiles))
                StatView(title: "Avg Miles Per Workout", value: String(format: "%.1f", averageAntelopeMiles))
            }
        }
        .padding()
        .background(Color.gray.opacity(0.1))
        .cornerRadius(10)
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

    private var totalMiles: Double {
        antelopeWorkouts.reduce(0) { $0 + $1.distance / 1609.34 }
    }
    
    private var averageAntelopeMiles: Double {
        antelopeWorkouts.isEmpty ? 0 : totalMiles / Double(antelopeWorkouts.count)
    }
    
    private var antelopeWorkouts: [DetailedWorkout] {
        workouts.filter { isAntelopeWorkout($0) }
    }

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
}

struct LastMonthModule: View {
    let workouts: [DetailedWorkout]

    var body: some View {
        VStack(alignment: .leading, spacing: 10) {
            Text("Last Month")
                .font(.title2)
                .fontWeight(.bold)

            HeatMapGrid(daysInMonth: daysInLastMonth, firstDayOfMonth: firstDayOfLastMonth, workouts: antelopeWorkouts)
            
            HStack {
                StatView(title: "Antelope Workouts", value: "\(antelopeWorkouts.count)") // Only counting Antelope workouts
                StatView(title: "Total Miles", value: String(format: "%.1f", totalMiles))
                StatView(title: "Avg Miles Per Workout", value: String(format: "%.1f", averageAntelopeMiles))
            }
        }
        .padding()
        .background(Color.gray.opacity(0.1))
        .cornerRadius(10)
    }
    
    private var daysInLastMonth: Int {
        let calendar = Calendar.current
        let lastMonth = calendar.date(byAdding: .month, value: -1, to: Date())
        let range = calendar.range(of: .day, in: .month, for: lastMonth ?? Date())
        return range?.count ?? 30
    }

    private var firstDayOfLastMonth: Int {
        let calendar = Calendar.current
        let lastMonth = calendar.date(byAdding: .month, value: -1, to: Date()) ?? Date()
        let startOfMonth = calendar.startOfMonth(for: lastMonth)
        return calendar.component(.weekday, from: startOfMonth) - 1
    }

    private var totalMiles: Double {
        antelopeWorkouts.reduce(0) { $0 + $1.distance / 1609.34 }
    }
    
    private var averageAntelopeMiles: Double {
        antelopeWorkouts.isEmpty ? 0 : totalMiles / Double(antelopeWorkouts.count)
    }
    
    private var antelopeWorkouts: [DetailedWorkout] {
        workouts.filter { isAntelopeWorkout($0) }
    }

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
}

struct ThisYearModule: View {
    let workouts: [DetailedWorkout]

    var body: some View {
        VStack(alignment: .leading, spacing: 10) {
            Text("This Year")
                .font(.title2)
                .fontWeight(.bold)
            
            Chart {
                ForEach(monthlyMiles, id: \.month) { item in
                    BarMark(
                        x: .value("Month", item.month),
                        y: .value("Miles", item.miles)
                    )
                }
            }
            .chartXAxis {
                AxisMarks(values: .automatic) { _ in
                    AxisGridLine(centered: true, stroke: StrokeStyle(lineWidth: 0))
                    AxisValueLabel(format: .dateTime.month(.abbreviated))
                }
            }
            .chartYAxis {
                AxisMarks(position: .leading)
            }
            .frame(height: 200)
        }
        .padding()
        .background(Color.gray.opacity(0.1))
        .cornerRadius(10)
    }
    
    private var monthlyMiles: [(month: Date, miles: Double)] {
        let calendar = Calendar.current
        let grouped = Dictionary(grouping: workouts) { workout in
            calendar.startOfMonth(for: workout.date)
        }
        let result = grouped.map { (month, workouts) in
            let miles = workouts.reduce(0.0) { $0 + $1.distance / 1609.34 }
            return (month: month, miles: miles)
        }
        return result.sorted { $0.month < $1.month }
    }
}

struct PastMonthsModule: View {
    let workoutsByMonth: [String: [DetailedWorkout]]
    @Binding var expandedMonths: Set<String>

    var body: some View {
        VStack(alignment: .leading, spacing: 10) {
            Text("Past Months")
                .font(.title2)
                .fontWeight(.bold)
            
            ForEach(sortedMonths, id: \.self) { month in
                Section(header: monthHeader(for: month)) {
                    if expandedMonths.contains(month) {
                        HeatMapGrid(
                            daysInMonth: daysInMonth(for: month),
                            firstDayOfMonth: firstDayOfMonth(for: month),
                            workouts: workoutsByMonth[month] ?? []
                        )
                        ForEach(workoutsByMonth[month]?.sorted(by: { $0.date > $1.date }) ?? [], id: \.id) { workout in
                            WorkoutRow(workout: workout)
                        }
                    }
                }
            }
        }
    }

    private var sortedMonths: [String] {
        workoutsByMonth.keys.sorted(by: { formatDateToDate($0) > formatDateToDate($1) })
    }

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

    private func monthHeader(for month: String) -> some View {
        let workouts = workoutsByMonth[month] ?? []
        let totalWorkouts = workouts.count
        let antelopeWorkouts = workouts.filter { isAntelopeWorkout($0) }.count

        return HStack {
            Text(month)
            Spacer()
            VStack(alignment: .trailing) {
                Text("\(totalWorkouts) total")
                Text("\(antelopeWorkouts) Antelope")
                    .font(.caption)
                    .foregroundColor(.secondary)
            }
        }
        .contentShape(Rectangle())
        .onTapGesture {
            toggleMonth(month)
        }
    }

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

    private func toggleMonth(_ month: String) {
        if expandedMonths.contains(month) {
            expandedMonths.remove(month)
        } else {
            expandedMonths.insert(month)
        }
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
        VStack(alignment: .leading, spacing: 5) {
            HStack {
                Text(HKWorkoutActivityType.name(for: workout.type))
                    .font(.headline)
                Spacer()
                Text(formatDate(workout.date))
                    .font(.caption)
                    .foregroundColor(.secondary)
            }
            Text("Distance: \(String(format: "%.2f", workout.distance / 1000)) km")
            Text("Duration: \(formatDuration(workout.duration))")
            if let calories = workout.calories {
                Text("Calories: \(String(format: "%.0f", calories)) kcal")
            }
        }
        .padding(8)
        .background(backgroundColorForWorkout)
        .cornerRadius(8)
    }

    private var backgroundColorForWorkout: Color {
        isAntelopeWorkout ? Color.green.opacity(0.2) : Color.gray.opacity(0.1)
    }

    private var isAntelopeWorkout: Bool {
        switch workout.type {
        case .running:
            return workout.distance >= 3218.69 // 2 miles
        case .cycling:
            return workout.distance >= 9656.06 // 6 miles
        default:
            return false
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
}

#Preview {
    PerformanceView()
        .environmentObject(HealthKitManager())
}
