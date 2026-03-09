//
//  LikedSongsView.swift
//  Dalmation
//
//  Created by Benjamin Parsons on 3/8/26.
//

import SwiftUI

struct LikedSongsView: View {

    @Environment(SpotifyAPIClient.self) private var api
    @Environment(PlaybackManager.self) private var playback

    @State private var savedTracks: [SavedTrack] = []
    @State private var isLoading = true
    @State private var errorMessage: String?

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 0) {
                header
                    .padding(.horizontal, 24)
                    .padding(.bottom, 24)

                if isLoading {
                    ProgressView()
                        .frame(maxWidth: .infinity)
                        .padding(.top, 60)
                } else if let error = errorMessage {
                    errorView(error)
                } else {
                    trackList
                }
            }
        }
        .navigationTitle("Liked Songs")
        .navigationBarTitleDisplayMode(.inline)
        .task { await loadTracks() }
    }

    // MARK: - Header

    private var header: some View {
        HStack(spacing: 20) {
            ZStack {
                RoundedRectangle(cornerRadius: 12)
                    .fill(LinearGradient(
                        colors: [.purple, .blue],
                        startPoint: .topLeading,
                        endPoint: .bottomTrailing
                    ))
                    .frame(width: 120, height: 120)
                Image(systemName: "heart.fill")
                    .font(.system(size: 48))
                    .foregroundStyle(.white)
            }

            VStack(alignment: .leading, spacing: 8) {
                Text("Liked Songs")
                    .font(.title2.bold())
                Text("\(savedTracks.count) songs")
                    .font(.subheadline)
                    .foregroundStyle(.secondary)
            }
        }
        .padding(.top, 24)
    }

    // MARK: - Track List

    private var trackList: some View {
        LazyVStack(spacing: 0) {
            ForEach(Array(savedTracks.enumerated()), id: \.offset) { index, saved in
                TrackRow(track: saved.track, index: index + 1) {
                    Task { await playback.play(uri: saved.track.uri) }
                }
                .padding(.horizontal, 24)

                if index < savedTracks.count - 1 {
                    Divider()
                        .padding(.leading, 24 + 24 + 14)
                }
            }
        }
        .padding(.bottom, 100)
    }

    // MARK: - Error

    private func errorView(_ message: String) -> some View {
        VStack(spacing: 12) {
            Image(systemName: "exclamationmark.triangle")
                .font(.largeTitle)
                .foregroundStyle(.secondary)
            Text(message)
                .foregroundStyle(.secondary)
            Button("Retry") { Task { await loadTracks() } }
        }
        .frame(maxWidth: .infinity)
        .padding(.top, 60)
    }

    // MARK: - Load

    private func loadTracks() async {
        isLoading = true
        errorMessage = nil
        do {
            let page = try await api.savedTracks(limit: 50)
            savedTracks = page.items
        } catch {
            errorMessage = error.localizedDescription
        }
        isLoading = false
    }
}
