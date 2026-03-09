//
//  SearchView.swift
//  Dalmation
//
//  Created by Benjamin Parsons on 3/8/26.
//

import SwiftUI

struct SearchView: View {

    @Environment(SpotifyAPIClient.self) private var api
    @Environment(PlaybackManager.self) private var playback

    @State private var query = ""
    @State private var results: SearchResults?
    @State private var isSearching = false
    @State private var searchTask: Task<Void, Never>?

    var body: some View {
        NavigationStack {
            Group {
                if query.isEmpty {
                    emptyState
                } else if isSearching {
                    ProgressView("Searching...")
                        .frame(maxWidth: .infinity, maxHeight: .infinity)
                } else if let results {
                    resultsList(results)
                }
            }
            .navigationTitle("Search")
            .searchable(text: $query, prompt: "Artists, songs, or podcasts")
            .onChange(of: query) { _, newValue in
                scheduleSearch(newValue)
            }
        }
    }

    // MARK: - Empty State

    private var emptyState: some View {
        VStack(spacing: 16) {
            Image(systemName: "magnifyingglass")
                .font(.system(size: 56))
                .foregroundStyle(.tertiary)
            Text("Search Spotify")
                .font(.title2.bold())
            Text("Find your favorite songs, albums, and artists.")
                .font(.subheadline)
                .foregroundStyle(.secondary)
                .multilineTextAlignment(.center)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .padding()
    }

    // MARK: - Results

    private func resultsList(_ results: SearchResults) -> some View {
        ScrollView {
            LazyVStack(alignment: .leading, spacing: 32) {

                // Tracks
                if let tracks = results.tracks?.items, !tracks.isEmpty {
                    section("Songs") {
                        LazyVStack(spacing: 0) {
                            ForEach(Array(tracks.prefix(10).enumerated()), id: \.element.id) { index, track in
                                TrackRow(track: track) {
                                    Task { await playback.play(uri: track.uri) }
                                }
                                if index < min(tracks.count, 10) - 1 {
                                    Divider()
                                }
                            }
                        }
                        .padding(.horizontal, 4)
                    }
                }

                // Albums
                if let albums = results.albums?.items, !albums.isEmpty {
                    section("Albums") {
                        ScrollView(.horizontal, showsIndicators: false) {
                            HStack(spacing: 16) {
                                ForEach(albums.prefix(10)) { album in
                                    albumCard(album)
                                }
                            }
                            .padding(.horizontal, 4)
                            .padding(.bottom, 4)
                        }
                    }
                }

                // Artists
                if let artists = results.artists?.items, !artists.isEmpty {
                    section("Artists") {
                        ScrollView(.horizontal, showsIndicators: false) {
                            HStack(spacing: 16) {
                                ForEach(artists.prefix(10)) { artist in
                                    artistCard(artist)
                                }
                            }
                            .padding(.horizontal, 4)
                            .padding(.bottom, 4)
                        }
                    }
                }
            }
            .padding(24)
            .padding(.bottom, 80)
        }
    }

    // MARK: - Cards

    private func albumCard(_ album: Album) -> some View {
        Button {
            Task { await playback.play(contextURI: album.uri) }
        } label: {
            VStack(alignment: .leading, spacing: 8) {
                ArtworkImage(url: album.artworkURL, size: 140)
                Text(album.name)
                    .font(.subheadline.weight(.medium))
                    .lineLimit(2)
                    .frame(width: 140, alignment: .leading)
                Text(album.artists.map(\.name).joined(separator: ", "))
                    .font(.caption)
                    .foregroundStyle(.secondary)
                    .lineLimit(1)
                    .frame(width: 140, alignment: .leading)
            }
        }
        .buttonStyle(.plain)
    }

    private func artistCard(_ artist: Artist) -> some View {
        VStack(spacing: 8) {
            AsyncImage(url: artist.imageURL) { image in
                image.resizable().aspectRatio(contentMode: .fill)
            } placeholder: {
                Circle().fill(.quaternary)
                    .overlay {
                        Image(systemName: "person.fill")
                            .font(.system(size: 40))
                            .foregroundStyle(.tertiary)
                    }
            }
            .frame(width: 120, height: 120)
            .clipShape(Circle())

            Text(artist.name)
                .font(.subheadline.weight(.medium))
                .lineLimit(2)
                .multilineTextAlignment(.center)
                .frame(width: 120)
        }
    }

    // MARK: - Section Helper

    private func section<Content: View>(_ title: String, @ViewBuilder content: () -> Content) -> some View {
        VStack(alignment: .leading, spacing: 12) {
            Text(title)
                .font(.title3.bold())
            content()
        }
    }

    // MARK: - Search

    private func scheduleSearch(_ newQuery: String) {
        searchTask?.cancel()
        guard !newQuery.trimmingCharacters(in: .whitespaces).isEmpty else {
            results = nil
            return
        }
        searchTask = Task {
            try? await Task.sleep(for: .milliseconds(400))
            guard !Task.isCancelled else { return }
            await performSearch(newQuery)
        }
    }

    private func performSearch(_ q: String) async {
        isSearching = true
        do {
            results = try await api.search(query: q, types: [.track, .album, .artist], limit: 10)
        } catch {
            // Keep previous results on error
        }
        isSearching = false
    }
}
