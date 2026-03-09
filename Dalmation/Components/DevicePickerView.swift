//
//  DevicePickerView.swift
//  Dalmation
//
//  Created by Benjamin Parsons on 3/8/26.
//

import SwiftUI

struct DevicePickerView: View {

    @Environment(SpotifyAPIClient.self) private var api
    @Environment(PlaybackManager.self) private var playback

    @State private var devices: [SpotifyDevice] = []
    @State private var isLoading = true
    @State private var errorMessage: String?

    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            Text("Connect to a Device")
                .font(.headline)
                .padding(.horizontal, 20)
                .padding(.top, 20)
                .padding(.bottom, 12)

            if isLoading {
                ProgressView()
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, 24)
            } else if let error = errorMessage {
                Text(error)
                    .font(.subheadline)
                    .foregroundStyle(.secondary)
                    .multilineTextAlignment(.center)
                    .padding()
                    .frame(maxWidth: .infinity)
            } else {
                if devices.isEmpty {
                    Text("No devices found.")
                        .font(.subheadline)
                        .foregroundStyle(.secondary)
                        .multilineTextAlignment(.center)
                        .padding(.horizontal)
                        .padding(.top, 8)
                        .frame(maxWidth: .infinity)
                } else {
                    ForEach(devices) { device in
                        deviceRow(device)
                        Divider().padding(.leading, 52)
                    }
                }

                Divider().padding(.top, 8)
                webPlayerButton
            }
        }
        .frame(minWidth: 280)
        .task { await loadDevices() }
    }

    private var webPlayerButton: some View {
        Button {
            UIApplication.shared.open(URL(string: "https://open.spotify.com")!)
        } label: {
            HStack(spacing: 14) {
                Image(systemName: "globe")
                    .font(.title3)
                    .frame(width: 28)
                    .foregroundStyle(.secondary)

                VStack(alignment: .leading, spacing: 2) {
                    Text("Open Spotify Web Player")
                        .font(.body)
                        .foregroundStyle(.primary)
                    Text("Opens in Safari — then come back here")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }
                Spacer()
                Image(systemName: "arrow.up.right")
                    .font(.caption)
                    .foregroundStyle(.tertiary)
            }
            .padding(.horizontal, 20)
            .padding(.vertical, 12)
            .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
    }

    private func deviceRow(_ device: SpotifyDevice) -> some View {
        Button {
            Task { await transfer(to: device) }
        } label: {
            HStack(spacing: 14) {
                Image(systemName: iconName(for: device.type))
                    .font(.title3)
                    .frame(width: 28)
                    .foregroundStyle(device.isActive ? .green : .primary)

                VStack(alignment: .leading, spacing: 2) {
                    Text(device.name)
                        .font(.body)
                        .foregroundStyle(.primary)
                        .lineLimit(1)
                    if device.isActive {
                        Text("Currently playing")
                            .font(.caption)
                            .foregroundStyle(.green)
                    } else if let volume = device.volumePercent {
                        Text("Volume \(volume)%")
                            .font(.caption)
                            .foregroundStyle(.secondary)
                    }
                }

                Spacer()

                if device.isActive {
                    Image(systemName: "checkmark")
                        .font(.subheadline.weight(.semibold))
                        .foregroundStyle(.green)
                }
            }
            .padding(.horizontal, 20)
            .padding(.vertical, 12)
            .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
    }

    private func transfer(to device: SpotifyDevice) async {
        guard let id = device.id else { return }
        do {
            try await api.transferPlayback(to: id)
            try? await Task.sleep(for: .milliseconds(800))
            await playback.refresh()
        } catch {
            errorMessage = error.localizedDescription
        }
    }

    private func loadDevices() async {
        isLoading = true
        errorMessage = nil
        do {
            devices = try await api.availableDevices()
        } catch {
            errorMessage = error.localizedDescription
        }
        isLoading = false
    }

    private func iconName(for type: String) -> String {
        switch type.lowercased() {
        case "computer":    return "desktopcomputer"
        case "smartphone":  return "iphone"
        case "speaker":     return "hifispeaker.fill"
        case "tv":          return "appletv.fill"
        case "tablet":      return "ipad"
        case "castvideo",
             "castaudio":   return "tv.and.hifispeaker.fill"
        default:            return "hifispeaker.2.fill"
        }
    }
}
