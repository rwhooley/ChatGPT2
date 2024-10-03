//
//  InstructionalScreensView.swift
//  ChatGPT2
//
//  Created by Ryan Whooley on 9/30/24.
//

import SwiftUI


import SwiftUI

struct InstructionalScreensView: View {
    @Binding var showInstructionalScreens: Bool
    @State private var currentPage = 0

    let pages: [AnyView] = [
        AnyView(ScreenOneView()),
        AnyView(ScreenTwoView()),
        AnyView(ScreenThreeView()),
        AnyView(ScreenFourView()),
        AnyView(ScreenFiveView()),
        AnyView(ScreenSixView())
    ]

    var body: some View {
        VStack {
            HStack {
                            Button(action: {
                                showInstructionalScreens = false // Dismiss the view
                            }) {
                                Image(systemName: "xmark.circle.fill")
                                    .font(.system(size: 24))
                                    .foregroundColor(.gray)
                                    .padding()
                            }
                            Spacer() // Pushes the X button to the left
                        }
            TabView(selection: $currentPage) {
                ForEach(0..<pages.count, id: \.self) { index in
                    pages[index]
                        .tag(index)
                }
            }
            
            .tabViewStyle(PageTabViewStyle(indexDisplayMode: .always))
            .animation(.easeInOut, value: currentPage)
            
//            HStack {
//                if currentPage > 0 {
//                    Button(action: {
//                        currentPage -= 1
//                    }) {
//                        Text("Previous")
//                            .padding()
//                            .background(Color.gray.opacity(0.3))
//                            .cornerRadius(8)
//                    }
//                }
//
//                Spacer()
//                
//
//                if currentPage < pages.count - 1 {
//                    Button(action: {
//                        currentPage += 1
//                    }) {
//                        Text("Next")
//                            .padding()
//                            .background(Color.blue.opacity(0.7))
//                            .foregroundColor(.white)
//                            .cornerRadius(8)
//                    }
//                } else {
//                    Button(action: {
//                        showInstructionalScreens = false
//                    }) {
//                        Text("Finish")
//                            .padding()
//                            .background(Color.green.opacity(0.7))
//                            .foregroundColor(.white)
//                            .cornerRadius(8)
//                    }
//                }
//            }
            
            .padding()
        }
    }
}

// Screen One: Creating an Account and Setting up your Fitness Tracker
struct ScreenOneView: View {
    var body: some View {
        VStack {
            Text("Welcome to")
                   .font(.title)
                   .multilineTextAlignment(.center) // Aligns the text in the center
               
               Text("Antelope Fitness Club")
                   .font(.title)
                   .multilineTextAlignment(.center) // Aligns the text in the center
                

            ScrollView {
                VStack(alignment: .leading, spacing: 10) {
                    Image("home_pic")
                        .resizable()       // Allows the image to be resized
                        .scaledToFit()     // Makes sure the image scales correctly to fit the available space
                        .padding()
                    
                    
                
                }
                .padding()
            }
        }
    }
}

struct ScreenTwoView: View {
    var body: some View {
        VStack {
            Text("Setup Guide")
                .font(.title)
                .padding()

            ScrollView {
                VStack(alignment: .leading, spacing: 10) {
//                    Text("Setup Guide")
//                        .font(.headline)
//                        .padding(.bottom)
                    
                    Text("1. Create an Account")
                        .font(.headline)

                    Text("You've made it this far! Congrats on the first step in your fitness journey.")
                        .font(.footnote)

                    Text("2. Ensure You Have a Fitness Tracker")
                        .font(.headline)

                    Text("Antelope requires a fitness tracking device to measure workouts such as an Apple Watch, WHOOP strap, FitBit, or Garmin.")
                        .font(.footnote)

                    Text("3. Sync Fitness Tracker with Apple Health")
                        .font(.headline)

                    Text("Antelope reads fitness data from Apple Health. Link your fitness tracker to Apple Health so that your workouts are published there. If your fitness tracker does not publish distance data to Apple Health, you will also need to connect a run tracking app like Strava, Nike Run Club, or Map My Run.")
                        .font(.footnote)
                    
                    Text("*Note - if you are doing workouts on services like Peleton or SoulCycle, you may need to link these accounts to Apple Health as well for Antelope to read them.")
                        .font(.footnote)
                    
                    Text("4. Connect Antelope to Apple Health")
                        .font(.headline)

                    Text("Connect your Antelope app to Apple Health in your profile so that we can track your workouts and progress. Test the connection by tapping Reset Sync button. When you do this, old workouts should become visible in your Performance section.")
                        .font(.footnote)
                }
                .padding()
            }
        }
    }
}

// Screen Two: Depositing Money and Managing Your Bank
struct ScreenThreeView: View {
    var body: some View {
        VStack {
            Text("Money & Balances")
                .font(.title)
                .padding()

            ScrollView {
                VStack(alignment: .leading, spacing: 10) {
                    Text("Deposit Money")
                        .font(.headline)

                    Text("Navigate to the Bank screen where you can securely deposit money into your Antelope account. Your Antelope balance can be used to invest in workout plans, contests, and team challenges.")
                        .font(.footnote)
                        .padding(.bottom)

                    Text("Managing Your Balance")
                        .font(.headline)

                    Text("The Bank section shows 3 balances: Total Balance, Free Balance, and Invested Balance.")
                        .font(.footnote)
                        .padding(.bottom)
                    
                    Text("1. Total Balance")
                        .font(.headline)
                    
                    Text("Total Balance is the sum of your Free Balance and Invested Balance.")
                        .font(.footnote)
                        .padding(.bottom)
                    
                    Text("2. Free Balance")
                        .font(.headline)
                    
                    Text("Free Balance is the amount of your total balance that is available to invest or withdraw.")
                        .font(.footnote)
                        .padding(.bottom)
                    
                    Text("3. Invested Balance")
                        .font(.headline)
                    
                    Text("Invested Balance is the money that you have invested into workout plans (Personal, Contests, and Teams). It remains locked until those workout plans have concluded and payouts have been made.")
                        .font(.footnote)
                }
                .padding()
            }
        }
    }
}

// Screen Three: Investing in Workout Plans
struct ScreenFourView: View {
    var body: some View {
        VStack {
            Text("Invest")
                .font(.title)
                .padding()

            ScrollView {
                VStack(alignment: .leading, spacing: 10) {
                    Text("Invest in Workout Plans")
                        .font(.headline)

                    Text("There are 3 types of workout plans and investments on Antelope:")
                        .font(.footnote)
                        .padding(.bottom)
                    
                    Text("1. Personal")
                        .font(.headline)

                    Text("Create a monthly workout plan for yourself and invest in it. Set a number of workouts for the month (4,8,12,16), chose an investment amount to see your potential bonus. Potential bonuses will vary depending on how you structure your monthly plan.")
                        .font(.footnote)
                        .padding(.bottom)
                    
                    Text("2. Contests")
                        .font(.headline)

                    Text("Challenge friends to compete in fitness contests. Set goals, invite friends, and invest money into the pot. Whoever completes the workouts first or completes the most workouts wins the pot.")
                        .font(.footnote)
                        .padding(.bottom)
                    
                    Text("3. Teams")
                        .font(.headline)

                    Text("Form a team with friends to hold each other accountable. You can invest in team-based fitness plans where everyone works towards the same goal.")
                        .font(.footnote)
                        .padding(.bottom)
                    
                }
                .padding()
            }
        }
    }
}

// Screen Four: Tracking Progress and Earning Rewards
struct ScreenFiveView: View {
    var body: some View {
        VStack {
            Text("Work Out")
                .font(.title)
                .padding()

            ScrollView {
                VStack(alignment: .leading, spacing: 10) {
                    Text("Tracking")
                        .font(.headline)

                    Text("Antelope automatically tracks your progress using your fitness tracker through Apple Health. Each time you complete a workout that qualifies, the app will log it and update your investment progress in real-time.")
                        .font(.footnote)
                        .padding(.bottom)
                    
                    Text("Workout Completion")
                        .font(.headline)

                    Text("Once you complete all the workouts you pledged for a specific plan or contest, you’ll earn back your invested money and any potential bonuses. Keep pushing to exceed your goals to earn more!")
                        .font(.footnote)
                }
                .padding()
            }
        }
    }
}

struct ScreenSixView: View {
    var body: some View {
        VStack {
            Text("Get Paid")
                .font(.title)
                .padding()

            ScrollView {
                VStack(alignment: .leading, spacing: 10) {
                    Text("Personal Investments")
                        .font(.headline)

                    Text("Personal investment payouts occur on the 1st of each month for the prior month's investments.")
                        .font(.footnote)
                        .padding(.bottom)
                    
                    Text("Contest & Team Investments")
                        .font(.headline)

                    Text("Payouts for contest and team investments occur the day after the end eate of each contest.")
                        .font(.footnote)
                }
                .padding()
            }
        }
    }
}


#Preview {
    InstructionalScreensView(showInstructionalScreens: .constant(true))
}
