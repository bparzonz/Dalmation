//
//  SpotifyModels.swift
//  Dalmation
//
//  Created by Benjamin Parsons on 3/8/26.
//

import Foundation

// MARK: - User

struct SpotifyUser: Decodable, Identifiable {
    let id: String
    let displayName: String?
    let email: String?
    let images: [SpotifyImage]?
    let country: String?

    var avatarURL: URL? { images?.first.flatMap { URL(string: $0.url) } }
}

// MARK: - Image

struct SpotifyImage: Decodable, Hashable {
    let url: String
    let width: Int?
    let height: Int?
}

// MARK: - Track

struct Track: Decodable, Identifiable, Hashable {
    let id: String
    let name: String
    let durationMs: Int
    let explicit: Bool
    let artists: [Artist]
    let album: Album
    let uri: String
    let previewUrl: String?

    var durationFormatted: String {
        let s = durationMs / 1000
        return String(format: "%d:%02d", s / 60, s % 60)
    }
}

// MARK: - Album

struct Album: Decodable, Identifiable, Hashable {
    let id: String
    let name: String
    let albumType: String
    let images: [SpotifyImage]
    let artists: [Artist]
    let releaseDate: String
    let totalTracks: Int
    let uri: String

    var artworkURL: URL? { images.first.flatMap { URL(string: $0.url) } }
}

// MARK: - Artist

struct Artist: Decodable, Identifiable, Hashable {
    let id: String
    let name: String
    let images: [SpotifyImage]?
    let uri: String
    let followers: ArtistFollowers?   // Only present on full artist objects
    let genres: [String]?             // Only present on full artist objects

    var imageURL: URL? { images?.first.flatMap { URL(string: $0.url) } }
}

struct ArtistFollowers: Decodable, Hashable {
    let total: Int
}

struct ArtistTopTracksResponse: Decodable {
    let tracks: [Track]
}

// MARK: - Playlist

struct Playlist: Decodable, Identifiable {
    let id: String
    let name: String
    let description: String?
    let images: [SpotifyImage]?
    let owner: PlaylistOwner
    let tracks: PlaylistTracksRef?
    let uri: String

    var artworkURL: URL? { images?.first.flatMap { URL(string: $0.url) } }
}

struct PlaylistOwner: Decodable {
    let id: String
    let displayName: String?
}

struct PlaylistTracksRef: Decodable {
    let total: Int
}

// MARK: - Paging

struct Paged<T: Decodable>: Decodable {
    let items: [T]
    let total: Int
    let limit: Int
    let offset: Int
    let next: String?

    var hasMore: Bool { next != nil }
}

// MARK: - Search

struct SearchResults: Decodable {
    let tracks: Paged<Track>?
    let albums: Paged<Album>?
    let artists: Paged<Artist>?
    let playlists: Paged<Playlist>?
}

// MARK: - Playback State

struct PlaybackState: Decodable {
    let isPlaying: Bool
    let progressMs: Int?
    let item: Track?
    let device: SpotifyDevice?
    let shuffleState: Bool
    let repeatState: String       // "off", "track", "context"
}

// MARK: - Device

struct SpotifyDevice: Decodable, Identifiable, Hashable {
    let id: String?
    let name: String
    let type: String              // "Computer", "Smartphone", "Speaker", etc.
    let volumePercent: Int?
    let isActive: Bool
}

struct DevicesResponse: Decodable {
    let devices: [SpotifyDevice]
}

// MARK: - Playlist Track Wrapper (GET /playlists/{id}/tracks)

struct PlaylistTrack: Decodable {
    let track: Track?             // nil if track was removed from Spotify
    let addedAt: String?
}

// MARK: - Saved Track Wrapper (GET /me/tracks)

struct SavedTrack: Decodable {
    let track: Track
    let addedAt: String
}

// MARK: - Recently Played (GET /me/player/recently-played)

struct RecentlyPlayedResponse: Decodable {
    let items: [RecentlyPlayedItem]
}

struct RecentlyPlayedItem: Decodable {
    let track: Track
    let playedAt: String
}

// MARK: - Recommendations (GET /recommendations)

struct RecommendationsResponse: Decodable {
    let tracks: [Track]
}
