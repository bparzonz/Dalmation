//
//  ArtistDetailView.swift
//  Dalmation
//
//  Created by Benjamin Parsons on 3/8/26.
//

import SwiftUI

struct ArtistDetailView: View {

    let artist: Artist

    @Environment(SpotifyAPIClient.self) private var api
    @Environment(PlaybackManager.self) private var playback

    @State private var fullArtist: Artist?
    @State private var topTracks: [Track] = []
    @State private var albums: [Album] = []
    @State private var isLoading = true
    @State private var errorMessage: String?

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 0) {
                header
                    .padding(.bottom, 28)

                if isLoading {
                    ProgressView()
                        .frame(maxWidth: .infinity)
                        .padding(.top, 60)
                } else if let error = errorMessage {
                    errorView(error)
                } else {
                    content
                }
            }
        }
        .navigationTitle(artist.name)
        .navigationBarTitleDisplayMode(.inline)
        .task { await load() }
    }

    // MARK: - Header

    private var header: some View {
        ZStack(alignment: .bottomLeading) {
            AsyncImage(url: (fullArtist ?? artist).imageURL) { image in
                image.resizable().aspectRatio(contentMode: .fill)
            } placeholder: {
                Rectangle().fill(.quaternary)
            }
            .frame(maxWidth: .infinity)
            .frame(height: 300)
            .clipped()
            .overlay {
                LinearGradient(
                    colors: [.clear, .black.opacity(0.7)],
                    startPoint: .center,
                    endPoint: .bottom
                )
            }

            VStack(alignment: .leading, spacing: 6) {
                Text(artist.name)
                    .font(.largeTitle.bold())
                    .foregroundStyle(.white)

                if let followers = (fullArtist ?? artist).followers {
                    Text("\(followers.total.formatted()) followers")
                        .font(.subheadline)
                        .foregroundStyle(.white.opacity(0.8))
                }

                if let genres = (fullArtist ?? artist).genres, !genres.isEmpty {
                    Text(genres.prefix(3).joined(separator: " · "))
                        .font(.caption)
                        .foregroundStyle(.white.opacity(0.6))
                }
            }
            .padding(20)
        }
    }

    // MARK: - Content

    private var content: some View {
        VStack(alignment: .leading, spacing: 32) {
            if !topTracks.isEmpty {
                topTracksSection
            }
            if !albums.isEmpty {
                albumsSection
            }
        }
        .padding(.bottom, 100)
    }

    // MARK: - Top Tracks

    private var topTracksSection: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("Popular")
                .font(.title2.bold())
                .padding(.horizontal, 24)

            LazyVStack(spacing: 0) {
                ForEach(Array(topTracks.prefix(10).enumerated()), id: \.element.id) { index, track in
                    TrackRow(track: track, index: index + 1) {
                        Task { await playback.play(uri: track.uri) }
                    }
                    .padding(.horizontal, 24)

                    if index < min(topTracks.count, 10) - 1 {
                        Divider().padding(.leading, 24 + 24 + 14)
                    }
                }
            }
        }
    }

    // MARK: - Albums

    private var albumsSection: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("Albums & Singles")
                .font(.title2.bold())
                .padding(.horizontal, 24)

            ScrollView(.horizontal, showsIndicators: false) {
                HStack(spacing: 16) {
                    ForEach(albums) { album in
                        Button {
                            Task { await playback.play(contextURI: album.uri) }
                        } label: {
                            VStack(alignment: .leading, spacing: 8) {
                                ArtworkImage(url: album.artworkURL, size: 140)
                                Text(album.name)
                                    .font(.subheadline.weight(.medium))
                                    .lineLimit(2)
                                    .frame(width: 140, alignment: .leading)
                                Text(album.releaseDate.prefix(4))
                                    .font(.caption)
                                    .foregroundStyle(.secondary)
                                    .frame(width: 140, alignment: .leading)
                            }
                        }
                        .buttonStyle(.plain)
                    }
                }
                .padding(.horizontal, 24)
                .padding(.bottom, 4)
            }
        }
    }

    // MARK: - Error

    private func errorView(_ message: String) -> some View {
        VStack(spacing: 12) {
            Image(systemName: "exclamationmark.triangle")
                .font(.largeTitle)
                .foregroundStyle(.secondary)
            Text(message)
                .foregroundStyle(.secondary)
            Button("Retry") { Task { await load() } }
        }
        .frame(maxWidth: .infinity)
        .padding(.top, 60)
    }

    // MARK: - Load

    private func load() async {
        isLoading = true
        errorMessage = nil

        async let artistTask = api.artist(id: artist.id)
        async let tracksTask = api.artistTopTracks(id: artist.id)
        async let albumsTask = api.artistAlbums(id: artist.id)

        fullArtist = try? await artistTask

        do { topTracks = try await tracksTask } catch { errorMessage = "Top tracks: \(error.localizedDescription)" }
        do { albums = try await albumsTask } catch {
            let existing = errorMessage.map { $0 + "\n" } ?? ""
            errorMessage = existing + "Albums: \(error.localizedDescription)"
        }

        isLoading = false
    }
}
