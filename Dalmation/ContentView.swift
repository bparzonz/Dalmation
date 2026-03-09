//
//  ContentView.swift
//  Dalmation
//
//  Created by Benjamin Parsons on 3/8/26.
//

import SwiftUI

struct ContentView: View {

    @Environment(SpotifyAuthManager.self) private var auth

    var body: some View {
        Group {
            switch auth.authState {
            case .unauthenticated, .authenticating:
                LoginView()
            case .authenticated:
                MainView()
            }
        }
        .animation(.easeInOut, value: auth.authState)
    }
}
