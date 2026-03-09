//
//  NowPlayingBar.swift
//  Dalmation
//
//  Created by Benjamin Parsons on 3/8/26.
//

import SwiftUI

struct NowPlayingBar: View {

    @Environment(PlaybackManager.self) private var playback

    @State private var showingDevicePicker = false
    @State private var displayedProgressMs: Double = 0
    @State private var isDragging = false

    var body: some View {
        VStack(spacing: 10) {
            HStack(spacing: 20) {
                trackInfo
                Divider().frame(height: 32)
                controls
                Divider().frame(height: 32)
                deviceButton
            }

            if playback.currentTrack != nil {
                seekBar
            }
        }
        .padding(.horizontal, 24)
        .padding(.vertical, 14)
        .glassBackgroundEffect()
        .onChange(of: playback.progressMs) { _, newValue in
            if !isDragging {
                displayedProgressMs = Double(newValue)
            }
        }
        // Tick forward every second while playing to keep bar smooth between polls
        .task(id: playback.isPlaying) {
            guard playback.isPlaying else { return }
            while !Task.isCancelled && playback.isPlaying {
                try? await Task.sleep(for: .seconds(1))
                guard !isDragging && playback.isPlaying else { continue }
                let max = Double(playback.currentTrack?.durationMs ?? 0)
                displayedProgressMs = min(displayedProgressMs + 1000, max)
            }
        }
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

    // MARK: - Seek Bar

    private var seekBar: some View {
        HStack(spacing: 8) {
            Text(formatMs(Int(displayedProgressMs)))
                .font(.caption2.monospacedDigit())
                .foregroundStyle(.secondary)
                .frame(width: 36, alignment: .trailing)

            Slider(
                value: $displayedProgressMs,
                in: 0...Double(max(playback.currentTrack?.durationMs ?? 1, 1))
            ) { editing in
                isDragging = editing
                if !editing {
                    Task { await playback.seek(to: Int(displayedProgressMs)) }
                }
            }

            Text(playback.currentTrack?.durationFormatted ?? "-:--")
                .font(.caption2.monospacedDigit())
                .foregroundStyle(.secondary)
                .frame(width: 36, alignment: .leading)
        }
    }

    // MARK: - Device Button

    private var deviceButton: some View {
        Button {
            showingDevicePicker = true
        } label: {
            Image(systemName: "hifispeaker.2.fill")
                .font(.subheadline)
                .foregroundStyle(playback.state?.device != nil ? .green : .secondary)
        }
        .buttonStyle(.plain)
        .popover(isPresented: $showingDevicePicker) {
            DevicePickerView()
        }
    }

    // MARK: - Helpers

    private func formatMs(_ ms: Int) -> String {
        let s = ms / 1000
        return String(format: "%d:%02d", s / 60, s % 60)
    }
}
