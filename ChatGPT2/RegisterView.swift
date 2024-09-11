//
//  RegisterView.swift
//  ChatGPT2
//
//  Created by Ryan Whooley on 8/25/24.
//

import SwiftUI
import FirebaseAuth
import FirebaseFirestore

struct RegisterView: View {
    @State private var firstName = ""
    @State private var lastName = ""
    @State private var email = ""
    @State private var password = ""
    @State private var confirmPassword = ""
    @State private var phoneNumber = ""
    @State private var errorMessage = ""
    @State private var showingAlert = false
    @Environment(\.presentationMode) var presentationMode
    
    var body: some View {
        VStack {
            Text("Create an Account")
                .font(.largeTitle)
                .fontWeight(.bold)
                .padding(.top, 50)
            
            VStack(spacing: 20) {
                TextField("First Name", text: $firstName)
                    .textFieldStyle(RoundedBorderTextFieldStyle())
                    .autocapitalization(.words)
                
                TextField("Last Name", text: $lastName)
                    .textFieldStyle(RoundedBorderTextFieldStyle())
                    .autocapitalization(.words)
                
                TextField("Email", text: $email)
                    .textFieldStyle(RoundedBorderTextFieldStyle())
                    .autocapitalization(.none)
                    .keyboardType(.emailAddress)
                
                TextField("Phone Number", text: $phoneNumber)
                    .textFieldStyle(RoundedBorderTextFieldStyle())
                    .keyboardType(.phonePad)
                
                SecureField("Password", text: $password)
                    .textFieldStyle(RoundedBorderTextFieldStyle())
                
                SecureField("Confirm Password", text: $confirmPassword)
                    .textFieldStyle(RoundedBorderTextFieldStyle())
                
                Button(action: registerUser) {
                    Text("Register")
                        .font(.headline)
                        .foregroundColor(.white)
                        .padding()
                        .frame(maxWidth: .infinity)
                        .background(Color.blue)
                        .cornerRadius(10)
                }
            }
            .padding(.horizontal)
            
            Spacer()
        }
        .navigationBarTitle("Register", displayMode: .inline)
        .alert(isPresented: $showingAlert) {
            Alert(title: Text("Registration Error"), message: Text(errorMessage), dismissButton: .default(Text("OK")))
        }
    }
    
    func registerUser() {
        if password != confirmPassword {
            errorMessage = "Passwords do not match"
            showingAlert = true
            return
        }
        
        if phoneNumber.isEmpty {
            errorMessage = "Phone number is required"
            showingAlert = true
            return
        }
        
        Auth.auth().createUser(withEmail: email, password: password) { authResult, error in
            if let error = error {
                errorMessage = error.localizedDescription
                showingAlert = true
            } else if let user = authResult?.user {
                // User created successfully, now save additional info
                let db = Firestore.firestore()
                db.collection("users").document(user.uid).setData([
                    "firstName": firstName,
                    "lastName": lastName,
                    "email": email,
                    "phoneNumber": phoneNumber
                ]) { err in
                    if let err = err {
                        print("Error writing user data: \(err)")
                    } else {
                        print("User data saved successfully")
                    }
                }
                print("User registered successfully")
                presentationMode.wrappedValue.dismiss()
            }
        }
    }
}

#Preview {
    RegisterView()
}
