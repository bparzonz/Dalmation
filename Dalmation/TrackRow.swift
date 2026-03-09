//
//  TrackRow.swift
//  Dalmation
//
//  Created by Benjamin Parsons on 3/8/26.
//

import SwiftUI

struct TrackRow: View {

    let track: Track
    let index: Int?
    let onTap: () -> Void

    init(track: Track, index: Int? = nil, onTap: @escaping () -> Void) {
        self.track = track
        self.index = index
        self.onTap = onTap
    }

    var body: some View {
        Button(action: onTap) {
            HStack(spacing: 14) {
                // Index or artwork
                if let index {
                    Text("\(index)")
                        .font(.callout.monospacedDigit())
                        .foregroundStyle(.secondary)
                        .frame(width: 24, alignment: .trailing)
                } else {
                    ArtworkImage(url: track.album.artworkURL, size: 48)
                }

                // Title + artist
                VStack(alignment: .leading, spacing: 3) {
                    Text(track.name)
                        .font(.body)
                        .lineLimit(1)
                        .foregroundStyle(.primary)

                    HStack(spacing: 4) {
                        if track.explicit {
                            Image(systemName: "e.square.fill")
                                .font(.caption2)
                                .foregroundStyle(.secondary)
                        }
                        Text(track.artists.map(\.name).joined(separator: ", "))
                            .font(.subheadline)
                            .foregroundStyle(.secondary)
                            .lineLimit(1)
                    }
                }

                Spacer()

                Text(track.durationFormatted)
                    .font(.subheadline.monospacedDigit())
                    .foregroundStyle(.tertiary)
            }
            .padding(.vertical, 6)
            .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
    }
}
