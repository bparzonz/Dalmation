//
//  HomeView.swift
//  Dalmation
//
//  Created by Benjamin Parsons on 3/8/26.
//

import SwiftUI

struct HomeView: View {

    @Environment(SpotifyAPIClient.self) private var api
    @Environment(PlaybackManager.self) private var playback
    @Environment(SpotifyAuthManager.self) private var auth

    @State private var user: SpotifyUser?
    @State private var playlists: [Playlist] = []
    @State private var recentTracks: [Track] = []
    @State private var recommended: [Track] = []
    @State private var isLoading = true

    var body: some View {
        NavigationStack {
            ScrollView {
                LazyVStack(alignment: .leading, spacing: 32) {

                    // Greeting
                    greeting
                        .padding(.horizontal, 24)
                        .padding(.top, 8)

                    // Liked Songs
                    NavigationLink {
                        LikedSongsView()
                    } label: {
                        likedSongsBanner
                            .padding(.horizontal, 24)
                    }
                    .buttonStyle(.plain)

                    // Recently Played
                    if !recentTracks.isEmpty {
                        trackSection("Recently Played", tracks: recentTracks)
                    }

                    // Recommended
                    if !recommended.isEmpty {
                        trackSection("Recommended For You", tracks: recommended)
                    }

                    // Playlists
                    if !playlists.isEmpty {
                        VStack(alignment: .leading, spacing: 12) {
                            Text("Your Playlists")
                                .font(.title2.bold())
                                .padding(.horizontal, 24)

                            ScrollView(.horizontal, showsIndicators: false) {
                                HStack(spacing: 16) {
                                    ForEach(playlists) { playlist in
                                        NavigationLink {
                                            PlaylistDetailView(playlist: playlist)
                                        } label: {
                                            playlistCard(playlist)
                                        }
                                        .buttonStyle(.plain)
                                    }
                                }
                                .padding(.horizontal, 24)
                                .padding(.bottom, 4)
                            }
                        }
                    }
                }
                .padding(.bottom, 100)
            }
            .navigationTitle("Home")
            .toolbar {
                ToolbarItem(placement: .topBarTrailing) {
                    Button("Log Out", systemImage: "rectangle.portrait.and.arrow.right") {
                        auth.logout()
                    }
                    .tint(.red)
                }
            }
            .task { await loadContent() }
        }
    }

    // MARK: - Greeting

    private var greeting: some View {
        VStack(alignment: .leading, spacing: 4) {
            Text(greetingText)
                .font(.largeTitle.bold())
            if let name = user?.displayName {
                Text(name)
                    .font(.title.bold())
                    .foregroundStyle(.green)
            }
        }
    }

    private var greetingText: String {
        let hour = Calendar.current.component(.hour, from: .now)
        switch hour {
        case 0..<12: return "Good morning,"
        case 12..<17: return "Good afternoon,"
        default:     return "Good evening,"
        }
    }

    // MARK: - Liked Songs Banner

    private var likedSongsBanner: some View {
        HStack(spacing: 16) {
            ZStack {
                RoundedRectangle(cornerRadius: 10)
                    .fill(LinearGradient(
                        colors: [.purple, .blue],
                        startPoint: .topLeading,
                        endPoint: .bottomTrailing
                    ))
                    .frame(width: 56, height: 56)
                Image(systemName: "heart.fill")
                    .font(.title2)
                    .foregroundStyle(.white)
            }

            VStack(alignment: .leading, spacing: 2) {
                Text("Liked Songs")
                    .font(.headline)
                Text("Your saved tracks")
                    .font(.subheadline)
                    .foregroundStyle(.secondary)
            }

            Spacer()

            Image(systemName: "chevron.right")
                .foregroundStyle(.tertiary)
        }
        .padding(16)
        .background(.regularMaterial, in: RoundedRectangle(cornerRadius: 14))
    }

    // MARK: - Track Section

    private func trackSection(_ title: String, tracks: [Track]) -> some View {
        VStack(alignment: .leading, spacing: 12) {
            Text(title)
                .font(.title2.bold())
                .padding(.horizontal, 24)

            ScrollView(.horizontal, showsIndicators: false) {
                HStack(spacing: 16) {
                    ForEach(tracks) { track in
                        trackCard(track)
                    }
                }
                .padding(.horizontal, 24)
                .padding(.bottom, 4)
            }
        }
    }

    private func trackCard(_ track: Track) -> some View {
        Button {
            Task { await playback.play(uri: track.uri) }
        } label: {
            VStack(alignment: .leading, spacing: 10) {
                ArtworkImage(url: track.album.artworkURL, size: 140)

                VStack(alignment: .leading, spacing: 3) {
                    Text(track.name)
                        .font(.subheadline.weight(.semibold))
                        .lineLimit(2)
                        .frame(width: 140, alignment: .leading)
                    Text(track.artists.map(\.name).joined(separator: ", "))
                        .font(.caption)
                        .foregroundStyle(.secondary)
                        .lineLimit(1)
                        .frame(width: 140, alignment: .leading)
                }
            }
        }
        .buttonStyle(.plain)
    }

    // MARK: - Playlist Card

    private func playlistCard(_ playlist: Playlist) -> some View {
        VStack(alignment: .leading, spacing: 10) {
            ArtworkImage(url: playlist.artworkURL, size: 160)

            VStack(alignment: .leading, spacing: 3) {
                Text(playlist.name)
                    .font(.subheadline.weight(.semibold))
                    .lineLimit(2)
                    .frame(width: 160, alignment: .leading)
                Text("\(playlist.tracks?.total ?? 0) songs")
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }
        }
    }

    // MARK: - Load

    private func loadContent() async {
        isLoading = true

        async let userTask = try? api.currentUser()
        async let playlistsTask = try? api.userPlaylists(limit: 20)
        async let recentTask = try? api.recentlyPlayed(limit: 20)
        async let topTracksTask = try? api.topTracks(limit: 5)

        user = await userTask
        playlists = await playlistsTask?.items ?? []
        recentTracks = await recentTask ?? []

        let seedIDs = (await topTracksTask ?? []).map(\.id)
        if !seedIDs.isEmpty {
            recommended = (try? await api.recommendations(seedTrackIDs: seedIDs, limit: 20)) ?? []
        }

        isLoading = false
    }
}
