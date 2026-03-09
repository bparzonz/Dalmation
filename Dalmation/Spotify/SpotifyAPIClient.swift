//
//  SpotifyAPIClient.swift
//  Dalmation
//
//  Created by Benjamin Parsons on 3/8/26.
//

import Foundation

// MARK: - Error

enum SpotifyAPIError: Error, LocalizedError {
    case unauthorized
    case notFound
    case noActiveDevice
    case forbidden
    case serverError(Int)
    case decodingError(Error)
    case unknown

    var errorDescription: String? {
        switch self {
        case .unauthorized:         return "Session expired. Please log in again."
        case .notFound:             return "Content not found."
        case .noActiveDevice:       return "No active Spotify device. Open Spotify on a device first."
        case .forbidden:            return "Access denied. A Spotify Premium account may be required."
        case .serverError(let c):   return "Spotify server error (\(c))."
        case .decodingError(let e): return "Unexpected response: \(e.localizedDescription)"
        case .unknown:              return "Something went wrong."
        }
    }
}

// MARK: - Client

@Observable
final class SpotifyAPIClient {

    private let baseURL = "https://api.spotify.com/v1"
    private let authManager: SpotifyAuthManager
    private var userMarket: String = "US"

    private let decoder: JSONDecoder = {
        let d = JSONDecoder()
        d.keyDecodingStrategy = .convertFromSnakeCase
        return d
    }()

    init(authManager: SpotifyAuthManager) {
        self.authManager = authManager
    }

    // MARK: - User

    func currentUser() async throws -> SpotifyUser {
        let user: SpotifyUser = try await request("/me")
        if let country = user.country { userMarket = country }
        return user
    }

    // MARK: - Search

    enum SearchType: String {
        case track, album, artist, playlist
    }

    func search(
        query: String,
        types: [SearchType] = [.track, .album, .artist],
        limit: Int = 20,
        offset: Int = 0
    ) async throws -> SearchResults {
        try await request("/search", queryItems: [
            .init(name: "q", value: query),
            .init(name: "type", value: types.map(\.rawValue).joined(separator: ",")),
            .init(name: "limit", value: "\(limit)"),
            .init(name: "offset", value: "\(offset)")
        ])
    }

    // MARK: - Library

    func userPlaylists(limit: Int = 50, offset: Int = 0) async throws -> Paged<Playlist> {
        try await request("/me/playlists", queryItems: [
            .init(name: "limit", value: "\(limit)"),
            .init(name: "offset", value: "\(offset)")
        ])
    }

    func playlistTracks(playlistID: String, limit: Int = 50, offset: Int = 0) async throws -> Paged<PlaylistTrack> {
        try await request("/playlists/\(playlistID)/tracks", queryItems: [
            .init(name: "limit", value: "\(limit)"),
            .init(name: "offset", value: "\(offset)")
        ])
    }

    func savedTracks(limit: Int = 50, offset: Int = 0) async throws -> Paged<SavedTrack> {
        try await request("/me/tracks", queryItems: [
            .init(name: "limit", value: "\(limit)"),
            .init(name: "offset", value: "\(offset)")
        ])
    }

    // MARK: - Artists

    func artist(id: String) async throws -> Artist {
        try await request("/artists/\(id)")
    }

    func artistTopTracks(id: String) async throws -> [Track] {
        let response: ArtistTopTracksResponse = try await request("/artists/\(id)/top-tracks")
        return response.tracks
    }

    func artistAlbums(id: String, limit: Int = 20) async throws -> [Album] {
        let page: Paged<Album> = try await request("/artists/\(id)/albums", queryItems: [
            .init(name: "include_groups", value: "album,single"),
            .init(name: "limit", value: "\(limit)")
        ])
        return page.items
    }

    // MARK: - Personalised

    func recentlyPlayed(limit: Int = 20) async throws -> [Track] {
        let response: RecentlyPlayedResponse = try await request("/me/player/recently-played", queryItems: [
            .init(name: "limit", value: "\(limit)")
        ])
        // Deduplicate — the same track can appear many times
        var seen = Set<String>()
        return response.items.compactMap { item in
            guard seen.insert(item.track.id).inserted else { return nil }
            return item.track
        }
    }

    func topTracks(limit: Int = 10, timeRange: String = "short_term") async throws -> [Track] {
        let page: Paged<Track> = try await request("/me/top/tracks", queryItems: [
            .init(name: "limit", value: "\(limit)"),
            .init(name: "time_range", value: timeRange)
        ])
        return page.items
    }

    func recommendations(seedTrackIDs: [String], limit: Int = 20) async throws -> [Track] {
        let seeds = seedTrackIDs.prefix(5).joined(separator: ",")
        let response: RecommendationsResponse = try await request("/recommendations", queryItems: [
            .init(name: "seed_tracks", value: seeds),
            .init(name: "limit", value: "\(limit)")
        ])
        return response.tracks
    }

    // MARK: - Playback

    /// Returns nil when no playback session is active (Spotify returns 204).
    func currentPlaybackState() async throws -> PlaybackState? {
        try await requestOptional("/me/player")
    }

    func availableDevices() async throws -> [SpotifyDevice] {
        let response: DevicesResponse = try await request("/me/player/devices")
        return response.devices
    }

    func transferPlayback(to deviceID: String) async throws {
        try await requestVoid("/me/player", method: "PUT", jsonBody: [
            "device_ids": [deviceID],
            "play": true
        ])
    }

    /// Play a specific track URI, or resume current playback if both args are nil.
    func play(uri: String? = nil, contextURI: String? = nil, deviceID: String? = nil) async throws {
        var body: [String: Any] = [:]
        if let contextURI { body["context_uri"] = contextURI }
        if let uri { body["uris"] = [uri] }

        var queryItems: [URLQueryItem] = []
        if let deviceID { queryItems.append(.init(name: "device_id", value: deviceID)) }

        try await requestVoid("/me/player/play", method: "PUT", jsonBody: body.isEmpty ? nil : body, queryItems: queryItems)
    }

    func pause(deviceID: String? = nil) async throws {
        var queryItems: [URLQueryItem] = []
        if let deviceID { queryItems.append(.init(name: "device_id", value: deviceID)) }
        try await requestVoid("/me/player/pause", method: "PUT", queryItems: queryItems)
    }

    func skipToNext() async throws {
        try await requestVoid("/me/player/next", method: "POST")
    }

    func skipToPrevious() async throws {
        try await requestVoid("/me/player/previous", method: "POST")
    }

    func seek(toMs positionMs: Int) async throws {
        try await requestVoid("/me/player/seek", method: "PUT", queryItems: [
            .init(name: "position_ms", value: "\(positionMs)")
        ])
    }

    func setVolume(_ percent: Int) async throws {
        let clamped = min(100, max(0, percent))
        try await requestVoid("/me/player/volume", method: "PUT", queryItems: [
            .init(name: "volume_percent", value: "\(clamped)")
        ])
    }

    func setShuffle(_ enabled: Bool) async throws {
        try await requestVoid("/me/player/shuffle", method: "PUT", queryItems: [
            .init(name: "state", value: enabled ? "true" : "false")
        ])
    }

    func setRepeat(_ mode: RepeatMode) async throws {
        try await requestVoid("/me/player/repeat", method: "PUT", queryItems: [
            .init(name: "state", value: mode.rawValue)
        ])
    }

    enum RepeatMode: String {
        case off, track, context
    }

    // MARK: - Core Networking

    private func request<T: Decodable>(
        _ path: String,
        method: String = "GET",
        jsonBody: [String: Any]? = nil,
        queryItems: [URLQueryItem] = []
    ) async throws -> T {
        let (data, status) = try await perform(path: path, method: method, jsonBody: jsonBody, queryItems: queryItems)

        if status == 401 {
            await authManager.refreshAccessToken()
            let (retryData, retryStatus) = try await perform(path: path, method: method, jsonBody: jsonBody, queryItems: queryItems)
            guard retryStatus != 401 else { throw SpotifyAPIError.unauthorized }
            try checkStatus(retryStatus)
            return try decode(retryData)
        }

        try checkStatus(status)
        return try decode(data)
    }

    private func requestOptional<T: Decodable>(
        _ path: String,
        method: String = "GET",
        queryItems: [URLQueryItem] = []
    ) async throws -> T? {
        let (data, status) = try await perform(path: path, method: method, queryItems: queryItems)

        if status == 204 || data.isEmpty { return nil }

        if status == 401 {
            await authManager.refreshAccessToken()
            let (retryData, retryStatus) = try await perform(path: path, method: method, queryItems: queryItems)
            guard retryStatus != 401 else { throw SpotifyAPIError.unauthorized }
            if retryStatus == 204 || retryData.isEmpty { return nil }
            try checkStatus(retryStatus)
            return try decode(retryData)
        }

        try checkStatus(status)
        return try decode(data)
    }

    private func requestVoid(
        _ path: String,
        method: String,
        jsonBody: [String: Any]? = nil,
        queryItems: [URLQueryItem] = []
    ) async throws {
        let (_, status) = try await perform(path: path, method: method, jsonBody: jsonBody, queryItems: queryItems)

        if status == 401 {
            await authManager.refreshAccessToken()
            let (_, retryStatus) = try await perform(path: path, method: method, jsonBody: jsonBody, queryItems: queryItems)
            guard retryStatus != 401 else { throw SpotifyAPIError.unauthorized }
            try checkStatus(retryStatus, isPlayback: true)
            return
        }

        try checkStatus(status, isPlayback: true)
    }

    private func perform(
        path: String,
        method: String = "GET",
        jsonBody: [String: Any]? = nil,
        queryItems: [URLQueryItem] = []
    ) async throws -> (Data, Int) {
        guard let token = TokenStore.shared.accessToken else {
            throw SpotifyAPIError.unauthorized
        }

        var components = URLComponents(string: baseURL + path)!
        if !queryItems.isEmpty {
            // Use urlQueryAllowed so commas in values (e.g. "album,single") are not percent-encoded
            components.percentEncodedQueryItems = queryItems.map {
                URLQueryItem(
                    name: $0.name.addingPercentEncoding(withAllowedCharacters: .urlQueryAllowed) ?? $0.name,
                    value: $0.value?.addingPercentEncoding(withAllowedCharacters: .urlQueryAllowed)
                )
            }
        }

        var request = URLRequest(url: components.url!)
        request.httpMethod = method
        request.setValue("Bearer \(token)", forHTTPHeaderField: "Authorization")

        if let body = jsonBody {
            request.setValue("application/json", forHTTPHeaderField: "Content-Type")
            request.httpBody = try? JSONSerialization.data(withJSONObject: body)
        }

        let (data, response) = try await URLSession.shared.data(for: request)
        let statusCode = (response as? HTTPURLResponse)?.statusCode ?? 0
        return (data, statusCode)
    }

    private func decode<T: Decodable>(_ data: Data) throws -> T {
        do {
            return try decoder.decode(T.self, from: data)
        } catch {
            throw SpotifyAPIError.decodingError(error)
        }
    }

    private func checkStatus(_ status: Int, isPlayback: Bool = false) throws {
        switch status {
        case 200...204: return
        case 401:       throw SpotifyAPIError.unauthorized
        case 403:       throw isPlayback ? SpotifyAPIError.noActiveDevice : SpotifyAPIError.forbidden
        case 404:       throw SpotifyAPIError.notFound
        case 500...599: throw SpotifyAPIError.serverError(status)
        default:        if status >= 400 { throw SpotifyAPIError.unknown }
        }
    }
}
