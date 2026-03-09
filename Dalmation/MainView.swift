//
//  MainView.swift
//  Dalmation
//
//  Created by Benjamin Parsons on 3/8/26.
//

import SwiftUI

struct MainView: View {

    @Environment(PlaybackManager.self) private var playback

    var body: some View {
        TabView {
            Tab("Home", systemImage: "house.fill") {
                HomeView()
            }

            Tab("Search", systemImage: "magnifyingglass") {
                SearchView()
            }

            Tab("Library", systemImage: "music.note.list") {
                LibraryView()
            }
        }
        .ornament(attachmentAnchor: .scene(.bottom)) {
            NowPlayingBar()
        }
        .task {
            playback.startPolling()
        }
    }
}
