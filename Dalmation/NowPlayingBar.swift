//
//  NowPlayingBar.swift
//  Dalmation
//
//  Created by Benjamin Parsons on 3/8/26.
//

import SwiftUI

struct NowPlayingBar: View {

    @Environment(PlaybackManager.self) private var playback

    var body: some View {
        HStack(spacing: 20) {
            trackInfo
            Divider().frame(height: 32)
            controls
        }
        .padding(.horizontal, 24)
        .padding(.vertical, 14)
        .glassBackgroundEffect()
    }

    // MARK: - Track Info

    private var trackInfo: some View {
        HStack(spacing: 12) {
            ArtworkImage(url: playback.currentTrack?.album.artworkURL, size: 40, cornerRadius: 6)

            VStack(alignment: .leading, spacing: 2) {
                if let track = playback.currentTrack {
                    Text(track.name)
                        .font(.subheadline.weight(.medium))
                        .lineLimit(1)
                        .frame(maxWidth: 200, alignment: .leading)

                    Text(track.artists.map(\.name).joined(separator: ", "))
                        .font(.caption)
                        .foregroundStyle(.secondary)
                        .lineLimit(1)
                        .frame(maxWidth: 200, alignment: .leading)
                } else {
                    Text("Not playing")
                        .font(.subheadline)
                        .foregroundStyle(.secondary)
                }
            }
        }
    }

    // MARK: - Controls

    private var controls: some View {
        HStack(spacing: 8) {
            Button {
                Task { await playback.skipToPrevious() }
            } label: {
                Image(systemName: "backward.fill")
                    .font(.title3)
            }
            .buttonStyle(.plain)
            .disabled(playback.currentTrack == nil)

            Button {
                Task { await playback.togglePlayPause() }
            } label: {
                Image(systemName: playback.isPlaying ? "pause.fill" : "play.fill")
                    .font(.title2)
                    .frame(width: 36, height: 36)
                    .contentTransition(.symbolEffect(.replace))
            }
            .buttonStyle(.plain)
            .disabled(playback.currentTrack == nil)

            Button {
                Task { await playback.skipToNext() }
            } label: {
                Image(systemName: "forward.fill")
                    .font(.title3)
            }
            .buttonStyle(.plain)
            .disabled(playback.currentTrack == nil)

            // Shuffle
            Button {
                Task { await playback.setShuffle(!(playback.state?.shuffleState ?? false)) }
            } label: {
                Image(systemName: "shuffle")
                    .font(.subheadline)
                    .foregroundStyle(playback.state?.shuffleState == true ? .green : .secondary)
            }
            .buttonStyle(.plain)
        }
    }
}
