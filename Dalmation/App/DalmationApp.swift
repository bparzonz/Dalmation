//
//  DalmationApp.swift
//  Dalmation
//
//  Created by Benjamin Parsons on 3/8/26.
//

import SwiftUI

@main
struct DalmationApp: App {

    @State private var appModel: AppModel
    @State private var authManager: SpotifyAuthManager
    @State private var apiClient: SpotifyAPIClient
    @State private var playbackManager: PlaybackManager

    init() {
        let auth = SpotifyAuthManager()
        let api = SpotifyAPIClient(authManager: auth)
        _appModel = State(initialValue: AppModel())
        _authManager = State(initialValue: auth)
        _apiClient = State(initialValue: api)
        _playbackManager = State(initialValue: PlaybackManager(api: api))
    }

    var body: some Scene {
        WindowGroup {
            ContentView()
                .environment(appModel)
                .environment(authManager)
                .environment(apiClient)
                .environment(playbackManager)
                .task {
                    await authManager.restoreSessionIfAvailable()
                }
        }
    }
}
