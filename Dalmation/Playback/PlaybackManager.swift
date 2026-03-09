//
//  PlaybackManager.swift
//  Dalmation
//
//  Created by Benjamin Parsons on 3/8/26.
//

import Foundation

@MainActor
@Observable
final class PlaybackManager {

    var state: PlaybackState?
    var errorMessage: String?

    private let api: SpotifyAPIClient
    private var pollingTask: Task<Void, Never>?

    init(api: SpotifyAPIClient) {
        self.api = api
    }

    // MARK: - Computed

    var currentTrack: Track? { state?.item }
    var isPlaying: Bool { state?.isPlaying ?? false }
    var progressMs: Int { state?.progressMs ?? 0 }

    // MARK: - Polling

    func startPolling() {
        pollingTask?.cancel()
        pollingTask = Task { [weak self] in
            while !Task.isCancelled {
                await self?.refresh()
                try? await Task.sleep(for: .seconds(3))
            }
        }
    }

    func stopPolling() {
        pollingTask?.cancel()
        pollingTask = nil
    }

    func refresh() async {
        do {
            state = try await api.currentPlaybackState()
        } catch {
            // Polling errors are silent — don't disrupt UI
        }
    }

    // MARK: - Commands

    func togglePlayPause() async {
        do {
            if isPlaying {
                try await api.pause()
            } else {
                try await api.play()
            }
            // Optimistic update
            if let s = state {
                state = PlaybackState(
                    isPlaying: !s.isPlaying,
                    progressMs: s.progressMs,
                    item: s.item,
                    device: s.device,
                    shuffleState: s.shuffleState,
                    repeatState: s.repeatState
                )
            }
        } catch {
            errorMessage = error.localizedDescription
        }
    }

    func skipToNext() async {
        do {
            try await api.skipToNext()
            try? await Task.sleep(for: .milliseconds(600))
            await refresh()
        } catch {
            errorMessage = error.localizedDescription
        }
    }

    func skipToPrevious() async {
        do {
            try await api.skipToPrevious()
            try? await Task.sleep(for: .milliseconds(600))
            await refresh()
        } catch {
            errorMessage = error.localizedDescription
        }
    }

    func play(uri: String? = nil, contextURI: String? = nil) async {
        do {
            try await api.play(uri: uri, contextURI: contextURI)
            try? await Task.sleep(for: .milliseconds(600))
            await refresh()
        } catch {
            errorMessage = error.localizedDescription
        }
    }

    func seek(to positionMs: Int) async {
        do {
            try await api.seek(toMs: positionMs)
            if let s = state {
                state = PlaybackState(
                    isPlaying: s.isPlaying,
                    progressMs: positionMs,
                    item: s.item,
                    device: s.device,
                    shuffleState: s.shuffleState,
                    repeatState: s.repeatState
                )
            }
        } catch {
            errorMessage = error.localizedDescription
        }
    }

    func setShuffle(_ enabled: Bool) async {
        do {
            try await api.setShuffle(enabled)
            if let s = state {
                state = PlaybackState(
                    isPlaying: s.isPlaying,
                    progressMs: s.progressMs,
                    item: s.item,
                    device: s.device,
                    shuffleState: enabled,
                    repeatState: s.repeatState
                )
            }
        } catch {
            errorMessage = error.localizedDescription
        }
    }
}
