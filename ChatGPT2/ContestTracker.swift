import SwiftUI
import Firebase
import Combine
import HealthKit

struct ContestTrackingModule: View {
    @StateObject var viewModel: ContestTrackingViewModel
    @State private var isExpanded = false

    let columns: [GridItem] = Array(repeating: .init(.flexible()), count: 5)
    
    var body: some View {
            VStack(alignment: .center, spacing: 20) {
                if viewModel.isLoading {
                    ProgressView("Loading contest data...")
                } else if let error = viewModel.errorMessage {
                    Text(error)
                        .foregroundColor(.red)
                        .padding()
                } else {
                    // Show the user progress grid
                    ForEach(viewModel.contest.members, id: \.self) { userEmail in
                        let firstName = viewModel.userNames[userEmail] ?? "User"
                        HStack {
                            Text(firstName)
                                .font(.system(size: 16, weight: .bold))
                                .frame(maxWidth: .infinity, alignment: .leading)
                                .padding(.trailing, 10)
                                .layoutPriority(1)

                            workoutProgressGrid(for: userEmail)
                                .frame(maxWidth: UIScreen.main.bounds.width * 0.5)
                        }
                    }

                    // Toggle to collapse or expand detailed workouts
                    Button(action: {
                        withAnimation {
                            isExpanded.toggle()
                        }
                    }) {
                        HStack {
                            Text(isExpanded ? "Hide Workouts" : "Show Workouts")
                                .foregroundColor(.white)
                                
                            Spacer()
                            Image(systemName: isExpanded ? "chevron.up" : "chevron.down")
                                .foregroundColor(.white)
                        }
                        .padding()
                        .background(Color.gray.opacity(0.2))
                        .cornerRadius(8)
                    }

                    if isExpanded {
                        // Display detailed workouts
                        if !viewModel.detailedWorkouts.isEmpty {
                            ForEach(viewModel.detailedWorkouts) { workout in
                                VStack(alignment: .leading, spacing: 10) {
                                    HStack {
                                        if let profileUrl = workout.userProfilePictureUrl {
                                            AsyncImage(url: URL(string: profileUrl)) { image in
                                                image.resizable()
                                                    .scaledToFit()
                                                    .frame(width: 40, height: 40)
                                                    .clipShape(Circle())
                                            } placeholder: {
                                                Circle()
                                                    .fill(Color.gray)
                                                    .frame(width: 40, height: 40)
                                            }
                                        }
                                        VStack(alignment: .leading) {
                                            Text("\(workout.userFirstName) \(workout.userLastName)")
                                                .font(.headline)
                                            Text("Date: \(workout.date, formatter: dateFormatter)")
                                        }
                                    }
                                    .padding(.bottom, 5)

                                    HStack {
                                                                        // Normalize distance to miles if necessary
                                                                        let distanceInMiles = workout.distance / 1609.34 // Assuming distance is in meters
                                                                        Text("Distance: \(distanceInMiles, specifier: "%.2f") miles")
                                                                        Spacer()

                                                                        // Normalize pace to minutes per mile
                                                                        if let paceInSeconds = workout.pace {
                                                                            let paceInMinutes = paceInSeconds / 60
                                                                            Text("Pace: \(paceInMinutes, specifier: "%.2f") min/mile")
                                                                        }
                                    }

                                    HStack {
                                        Text("Duration: \(formatDuration(workout.duration))")
                                        Spacer()
                                        if let avgHR = workout.averageHeartRate {
                                            Text("Avg HR: \(avgHR, specifier: "%.0f") bpm")
                                        }
                                        if let maxHR = workout.maxHeartRate {
                                            Text("Max HR: \(maxHR, specifier: "%.0f") bpm")
                                        }
                                    }

                                    if let steps = workout.stepsCount {
                                        Text("Steps: \(steps, specifier: "%.0f")")
                                    }

                                    if let routeImageUrl = workout.routeImageUrl {
                                        Text("Route:")
                                            .font(.headline)
                                        
                                        AsyncImage(url: URL(string: routeImageUrl)) { image in
                                            image.resizable()
                                                .scaledToFit()
                                                .frame(maxHeight: 200)
                                                .cornerRadius(8)
                                        } placeholder: {
                                            Rectangle()
                                                .fill(Color.gray.opacity(0.3))
                                                .frame(maxHeight: 200)
                                                .cornerRadius(8)
                                        }
                                    }
                                }
                                .padding()
                                .background(Color.gray.opacity(0.1))
                                .cornerRadius(8)
                            }
                        } else {
                            Text("No qualifying workouts found.")
                                .foregroundColor(.secondary)
                        }
                    }
                }
            }
            .padding()
            .background(Color.white.opacity(0.1))
            .cornerRadius(16)
            .shadow(radius: 5)
            .onAppear {
                viewModel.fetchQualifyingWorkouts()
            }
        }

    // Dynamically calculate the number of columns and adjust the size of the squares
    private func workoutProgressGrid(for userEmail: String) -> some View {
        let completedWorkouts = viewModel.getQualifyingWorkoutsCount(for: userEmail)
        let totalWorkouts = viewModel.contest.numberOfWorkouts

        // Dynamically calculate available width after leaving space for the name label
        let availableWidth = UIScreen.main.bounds.width * 0.5  // Assign 60% of the screen width to the progress grid
        let squareSpacing: CGFloat = 6  // Spacing between squares
        let minSquareSize: CGFloat = 18  // Minimum size for squares

        // Calculate number of squares in one row based on available width
        let maxColumns = Int(availableWidth / (minSquareSize + squareSpacing))
        let columns = min(maxColumns, totalWorkouts)

        // Calculate the square size dynamically
        let squareSize = (availableWidth - CGFloat(columns - 1) * squareSpacing) / CGFloat(columns)

        // Calculate the number of rows required
        let rows = Int(ceil(Double(totalWorkouts) / Double(columns)))

        return VStack(spacing: squareSpacing) {
            ForEach(0..<rows, id: \.self) { row in
                HStack(spacing: squareSpacing) {
                    ForEach(0..<columns, id: \.self) { column in
                        let index = row * columns + column
                        if index < totalWorkouts {
                            ZStack {
                                RoundedRectangle(cornerRadius: 6)
                                    .fill(index < completedWorkouts ? Color.green : Color.gray.opacity(0.3))
                                    .frame(width: squareSize, height: squareSize)

                                if index < completedWorkouts {
                                    Text("✔️")
                                        .font(.caption)
                                        .foregroundColor(.white)
                                }
                            }
                        } else {
                            Spacer().frame(width: squareSize, height: squareSize)
                        }
                    }
                }
            }
        }
    }

   


    private var dateFormatter: DateFormatter {
        let formatter = DateFormatter()
        formatter.dateStyle = .short
        return formatter
    }

    private func formatDuration(_ duration: TimeInterval) -> String {
        let hours = Int(duration) / 3600
        let minutes = (Int(duration) % 3600) / 60
        let seconds = Int(duration) % 60

        return String(format: "%02d:%02d:%02d", hours, minutes, seconds)
    }
}


// ProgressBox can be a simple box showing progress
struct ProgressBox: View {
    let index: Int
    
    var body: some View {
        ZStack {
            RoundedRectangle(cornerRadius: 8)
                .fill(Color.green.opacity(0.8))
                .frame(width: 50, height: 50)
            
            Text("\(index + 1)")
                .font(.headline)
                .foregroundColor(.white)
        }
    }
}


class ContestTrackingViewModel: ObservableObject {
    @Published var contest: Contest
    @Published var isLoading = true
    @Published var errorMessage: String?
    @Published var userNames: [String: String] = [:]
    @Published var qualifyingWorkouts: [String: Int] = [:]
    @Published var detailedWorkouts: [DetailedWorkout] = []  // Add detailed workouts
    
    private var db = Firestore.firestore()
    private var cancellables = Set<AnyCancellable>()
    
    init(contest: Contest) {
        self.contest = contest
        fetchUserNames()
    }

    func fetchQualifyingWorkouts() {
        isLoading = true
        qualifyingWorkouts = [:]
        detailedWorkouts = [] // Clear existing workouts

        let workoutsRef = db.collection("workouts")
        let group = DispatchGroup()

        for userEmail in contest.members {
            group.enter()

            // Fetch the user ID for the email
            db.collection("users").whereField("email", isEqualTo: userEmail).getDocuments { [weak self] (userSnapshot, userError) in
                guard let self = self, let userDoc = userSnapshot?.documents.first else {
                    print("Error fetching user ID for email \(userEmail)")
                    group.leave()
                    return
                }

                let userId = userDoc.documentID
                
                // Fetch workouts for this user that match contest parameters
                workoutsRef
                    .whereField("userId", isEqualTo: userId)
                    .whereField("date", isGreaterThanOrEqualTo: self.contest.startDate)
                    .whereField("date", isLessThanOrEqualTo: self.contest.endDate)
                    .getDocuments { (snapshot, error) in
                        defer { group.leave() }
                        
                        if let error = error {
                            print("Error fetching workouts for user \(userId): \(error.localizedDescription)")
                            return
                        }
                        
                        guard let snapshot = snapshot else {
                            print("No workouts found for user \(userId)")
                            return
                        }

                        // Now you can filter the snapshot documents
                        let qualifyingWorkouts = snapshot.documents.filter { document in
                            guard let distance = document.data()["distance"] as? Double,
                                  let pace = document.data()["pace"] as? Double else {
                                print("Workout data is missing distance or pace")
                                return false
                            }
                            
                            let paceInMinutes = pace / 60.0
                            let isDistanceValid = distance >= self.contest.distance
                            let isPaceValid = paceInMinutes <= self.contest.pace
                            
                            print("Checking workout: Distance=\(distance), Pace=\(paceInMinutes)")
                            print("Contest requirements: Distance=\(self.contest.distance), Pace=\(self.contest.pace)")
                            
                            return isDistanceValid && isPaceValid
                        }

                        // Update qualifying workout counts
                        DispatchQueue.main.async {
                            self.qualifyingWorkouts[userEmail] = qualifyingWorkouts.count

                            // For each qualifying workout, create a DetailedWorkout and append it to detailedWorkouts
                            for document in qualifyingWorkouts {
                                if let detailedWorkout = self.createDetailedWorkout(from: document, for: userEmail) {
                                    self.detailedWorkouts.append(detailedWorkout)
                                }
                            }
                        }
                    }
            }
        }

        group.notify(queue: .main) { [weak self] in
            guard let self = self else { return }
            self.isLoading = false
        }
    }





    private func createDetailedWorkout(from document: DocumentSnapshot, for userEmail: String) -> DetailedWorkout? {
        let data = document.data() ?? [:]
        
        let date = (data["date"] as? Timestamp)?.dateValue() ?? Date()

        // Fetch user name from userNames dictionary if available
        let userName = userNames[userEmail] ?? "Unknown Unknown"
        let nameComponents = userName.split(separator: " ")
        let userFirstName = nameComponents.first ?? "Unknown"
        let userLastName = nameComponents.count > 1 ? nameComponents[1] : "Unknown"

        return DetailedWorkout(
            id: UUID(uuidString: data["id"] as? String ?? "") ?? UUID(),
            type: HKWorkoutActivityType(rawValue: data["type"] as? UInt ?? 0) ?? .other,
            distance: data["distance"] as? Double ?? 0.0,
            duration: data["duration"] as? TimeInterval ?? 0.0,
            calories: data["calories"] as? Double ?? 0.0,
            date: date,
            averageHeartRate: data["averageHeartRate"] as? Double,
            maxHeartRate: data["maxHeartRate"] as? Double,
            stepsCount: data["stepsCount"] as? Double,
            pace: data["pace"] as? TimeInterval,
            routeImageUrl: data["routeImageUrl"] as? String,
            intensity: WorkoutIntensity(rawValue: data["intensity"] as? String ?? "moderate") ?? .moderate,
            averageCadence: data["averageCadence"] as? Double,
            weather: data["weather"] as? String,
            sourceName: data["sourceName"] as? String,
            userFirstName: String(userFirstName),  // Assign from userNames lookup
            userLastName: String(userLastName),    // Assign from userNames lookup
            userProfilePictureUrl: data["userProfilePictureUrl"] as? String
        )
    }



    func getQualifyingWorkoutsCount(for userId: String) -> Int {
        return qualifyingWorkouts[userId] ?? 0
    }

    private func fetchUserNames() {
        let userEmails = contest.members
        let group = DispatchGroup()

        for userEmail in userEmails {
            group.enter()
            db.collection("users").whereField("email", isEqualTo: userEmail).getDocuments { [weak self] (snapshot: QuerySnapshot?, error: Error?) in
                defer { group.leave() }
                guard let self = self else { return }

                if let document = snapshot?.documents.first {
                    let data = document.data()

                    // Ensure that the correct fields exist in the Firestore document
                    let firstName = data["firstName"] as? String ?? "Unknown"
                    let lastName = data["lastName"] as? String ?? "Unknown"

                    // Update userNames dictionary
                    DispatchQueue.main.async {
                        self.userNames[userEmail] = "\(firstName) \(lastName)"
                        print("Fetched name: \(firstName) \(lastName) for email: \(userEmail)")
                    }
                } else {
                    print("User document not found for email: \(userEmail)")
                }
            }
        }

        group.notify(queue: .main) {
            print("All user first names fetched")
        }
    }


}
