//
//  OfferView.swift
//  ChatGPT2
//
//  Created by Ryan Whooley on 10/2/24.
//

import SwiftUI

struct OfferView: View {
    let offer: String
    let imageName: String // You can pass the image name dynamically

    var body: some View {
        VStack {
            // Circle image with the offer picture
            Image(imageName)
                .resizable()
                .scaledToFill()
                .frame(width: 60, height: 60) // Circle dimensions
                .clipShape(Circle())
                .overlay(Circle().stroke(Color.gray, lineWidth: 0.5)) // Add a border around the circle
//                .padding(.top)

            // Text beneath the circle
            Text(offer)
                .font(.caption)
                .foregroundColor(.primary)
                .padding(.top, 3) // Add some space between the circle and text
        }
        .frame(width: 100) // Adjust width to accommodate both image and text
        .padding(.top, 4)
        .padding(.bottom, 4)
    }
}

