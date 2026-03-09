//
//  LoginView.swift
//  Dalmation
//
//  Created by Benjamin Parsons on 3/8/26.
//

import SwiftUI

struct LoginView: View {

    @Environment(SpotifyAuthManager.self) private var auth

    var body: some View {
        VStack(spacing: 40) {
            VStack(spacing: 16) {
                Image(systemName: "music.note.house.fill")
                    .font(.system(size: 80))
                    .foregroundStyle(.green)
                    .symbolEffect(.pulse, isActive: auth.authState == .authenticating)

                Text("Dalmation")
                    .font(.extraLargeTitle.bold())

                Text("Your Spotify music library on Vision Pro")
                    .font(.title3)
                    .foregroundStyle(.secondary)
                    .multilineTextAlignment(.center)
            }

            VStack(spacing: 16) {
                Button(action: { auth.login() }) {
                    Label("Connect with Spotify", systemImage: "music.note.list")
                        .font(.headline)
                        .padding(.horizontal, 32)
                        .padding(.vertical, 14)
                }
                .buttonStyle(.borderedProminent)
                .tint(.green)
                .disabled(auth.authState == .authenticating)

                if auth.authState == .authenticating {
                    HStack(spacing: 8) {
                        ProgressView()
                        Text("Opening Spotify login...")
                            .font(.subheadline)
                            .foregroundStyle(.secondary)
                    }
                }

                if let message = auth.errorMessage {
                    Text(message)
                        .foregroundStyle(.red)
                        .font(.subheadline)
                        .multilineTextAlignment(.center)
                        .padding(.horizontal)
                }
            }
        }
        .padding(60)
        .frame(minWidth: 500)
    }
}

#Preview(windowStyle: .automatic) {
    LoginView()
        .environment(SpotifyAuthManager())
}
