//
//  LibraryView.swift
//  Dalmation
//
//  Created by Benjamin Parsons on 3/8/26.
//

import SwiftUI

struct LibraryView: View {

    @Environment(SpotifyAPIClient.self) private var api
    @Environment(PlaybackManager.self) private var playback

    @State private var playlists: [Playlist] = []
    @State private var isLoading = true
    @State private var errorMessage: String?

    var body: some View {
        NavigationStack {
            Group {
                if isLoading {
                    ProgressView("Loading library...")
                        .frame(maxWidth: .infinity, maxHeight: .infinity)
                } else if let error = errorMessage {
                    errorView(error)
                } else {
                    playlistList
                }
            }
            .navigationTitle("Your Library")
        }
        .task { await loadPlaylists() }
    }

    // MARK: - Playlist List

    private var playlistList: some View {
        List {
            // Liked Songs
            NavigationLink {
                LikedSongsView()
            } label: {
                HStack(spacing: 14) {
                    ZStack {
                        RoundedRectangle(cornerRadius: 6)
                            .fill(LinearGradient(
                                colors: [.purple, .blue],
                                startPoint: .topLeading,
                                endPoint: .bottomTrailing
                            ))
                            .frame(width: 48, height: 48)
                        Image(systemName: "heart.fill")
                            .foregroundStyle(.white)
                    }

                    VStack(alignment: .leading, spacing: 3) {
                        Text("Liked Songs")
                            .font(.body)
                        Text("Playlist")
                            .font(.subheadline)
                            .foregroundStyle(.secondary)
                    }
                }
                .padding(.vertical, 4)
            }

            // User Playlists
            ForEach(playlists) { playlist in
                NavigationLink {
                    PlaylistDetailView(playlist: playlist)
                } label: {
                    HStack(spacing: 14) {
                        ArtworkImage(url: playlist.artworkURL, size: 48, cornerRadius: 6)

                        VStack(alignment: .leading, spacing: 3) {
                            Text(playlist.name)
                                .font(.body)
                                .lineLimit(1)
                            Text("\(playlist.tracks.total) songs")
                                .font(.subheadline)
                                .foregroundStyle(.secondary)
                        }
                    }
                    .padding(.vertical, 4)
                }
            }
        }
        .listStyle(.inset)
    }

    // MARK: - Error

    private func errorView(_ message: String) -> some View {
        VStack(spacing: 12) {
            Image(systemName: "exclamationmark.triangle")
                .font(.largeTitle)
                .foregroundStyle(.secondary)
            Text(message)
                .foregroundStyle(.secondary)
            Button("Retry") { Task { await loadPlaylists() } }
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
    }

    // MARK: - Load

    private func loadPlaylists() async {
        isLoading = true
        errorMessage = nil
        do {
            let page = try await api.userPlaylists(limit: 50)
            playlists = page.items
        } catch {
            errorMessage = error.localizedDescription
        }
        isLoading = false
    }
}
