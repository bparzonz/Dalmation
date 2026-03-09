//
//  PlaylistDetailView.swift
//  Dalmation
//
//  Created by Benjamin Parsons on 3/8/26.
//

import SwiftUI

struct PlaylistDetailView: View {

    let playlist: Playlist

    @Environment(SpotifyAPIClient.self) private var api
    @Environment(PlaybackManager.self) private var playback

    @State private var tracks: [PlaylistTrack] = []
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
        .navigationTitle(playlist.name)
        .navigationBarTitleDisplayMode(.inline)
        .task { await loadTracks() }
    }

    // MARK: - Header

    private var header: some View {
        HStack(spacing: 20) {
            ArtworkImage(url: playlist.artworkURL, size: 120)

            VStack(alignment: .leading, spacing: 8) {
                Text(playlist.name)
                    .font(.title2.bold())
                    .lineLimit(2)

                if let description = playlist.description, !description.isEmpty {
                    Text(description)
                        .font(.subheadline)
                        .foregroundStyle(.secondary)
                        .lineLimit(3)
                }

                Text("\(playlist.tracks?.total ?? 0) songs · \(playlist.owner.displayName ?? playlist.owner.id)")
                    .font(.caption)
                    .foregroundStyle(.tertiary)

                Button {
                    Task { await playback.play(contextURI: playlist.uri) }
                } label: {
                    Label("Play", systemImage: "play.fill")
                        .font(.headline)
                        .padding(.horizontal, 20)
                        .padding(.vertical, 10)
                }
                .buttonStyle(.borderedProminent)
                .tint(.green)
            }
        }
        .padding(.top, 24)
    }

    // MARK: - Track List

    private var trackList: some View {
        LazyVStack(spacing: 0) {
            ForEach(Array(tracks.enumerated()), id: \.offset) { index, playlistTrack in
                if let track = playlistTrack.track {
                    TrackRow(track: track, index: index + 1) {
                        Task { await playback.play(uri: track.uri) }
                    }
                    .padding(.horizontal, 24)

                    if index < tracks.count - 1 {
                        Divider()
                            .padding(.leading, 24 + 24 + 14) // align past index column
                    }
                }
            }
        }
        .padding(.bottom, 100) // space for NowPlayingBar ornament
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
            let page = try await api.playlistTracks(playlistID: playlist.id, limit: 100)
            tracks = page.items
        } catch {
            errorMessage = error.localizedDescription
        }
        isLoading = false
    }
}
