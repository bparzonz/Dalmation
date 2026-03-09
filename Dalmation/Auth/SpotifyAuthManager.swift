//
//  SpotifyAuthManager.swift
//  Dalmation
//
//  Created by Benjamin Parsons on 3/8/26.
//

import Foundation
import AuthenticationServices
import CryptoKit
import UIKit

// MARK: - Configuration
// Set SPOTIFY_CLIENT_ID in Config.xcconfig (see Config.xcconfig.example)
private let clientID: String = Bundle.main.infoDictionary?["SpotifyClientID"] as? String ?? ""
private let redirectURI = "dalmation://spotify-callback"
private let scopes = [
    "user-read-playback-state",
    "user-modify-playback-state",
    "user-read-currently-playing",
    "playlist-read-private",
    "playlist-read-collaborative",
    "user-library-read",
    "user-read-private",
    "user-read-email",
    "user-read-recently-played",
    "user-top-read"
].joined(separator: " ")

@MainActor
@Observable
final class SpotifyAuthManager: NSObject {

    enum AuthState: Equatable {
        case unauthenticated
        case authenticating
        case authenticated
    }

    var authState: AuthState = .unauthenticated
    var errorMessage: String?

    private var codeVerifier: String?
    private var authSession: ASWebAuthenticationSession?

    // MARK: - Public

    func login() {
        errorMessage = nil
        let verifier = generateCodeVerifier()
        codeVerifier = verifier
        let challenge = generateCodeChallenge(from: verifier)

        var components = URLComponents(string: "https://accounts.spotify.com/authorize")!
        components.queryItems = [
            .init(name: "client_id", value: clientID),
            .init(name: "response_type", value: "code"),
            .init(name: "redirect_uri", value: redirectURI),
            .init(name: "code_challenge_method", value: "S256"),
            .init(name: "code_challenge", value: challenge),
            .init(name: "scope", value: scopes)
        ]

        guard let url = components.url else { return }
        authState = .authenticating

        let session = ASWebAuthenticationSession(
            url: url,
            callbackURLScheme: "dalmation"
        ) { [weak self] callbackURL, error in
            Task { @MainActor in
                await self?.handleCallback(url: callbackURL, error: error)
            }
        }
        session.presentationContextProvider = self
        session.prefersEphemeralWebBrowserSession = false
        authSession = session
        session.start()
    }

    func logout() {
        TokenStore.shared.clearTokens()
        authState = .unauthenticated
    }

    func restoreSessionIfAvailable() async {
        guard TokenStore.shared.refreshToken != nil else {
            authState = .unauthenticated
            return
        }
        // Access token exists — treat as authenticated and let the API client
        // trigger a refresh on the first 401 response.
        if TokenStore.shared.accessToken != nil {
            authState = .authenticated
        } else {
            await refreshAccessToken()
        }
    }

    func refreshAccessToken() async {
        guard let refreshToken = TokenStore.shared.refreshToken else {
            authState = .unauthenticated
            return
        }

        var request = URLRequest(url: URL(string: "https://accounts.spotify.com/api/token")!)
        request.httpMethod = "POST"
        request.setValue("application/x-www-form-urlencoded", forHTTPHeaderField: "Content-Type")
        request.httpBody = formEncoded([
            "client_id": clientID,
            "grant_type": "refresh_token",
            "refresh_token": refreshToken
        ])

        do {
            let (data, _) = try await URLSession.shared.data(for: request)
            let response = try JSONDecoder().decode(TokenResponse.self, from: data)
            TokenStore.shared.save(
                accessToken: response.access_token,
                refreshToken: response.refresh_token ?? refreshToken
            )
            authState = .authenticated
        } catch {
            authState = .unauthenticated
            errorMessage = "Session expired. Please log in again."
        }
    }

    // MARK: - Private

    private func handleCallback(url: URL?, error: Error?) async {
        if let error {
            let nsError = error as NSError
            if nsError.code == ASWebAuthenticationSessionError.canceledLogin.rawValue {
                authState = .unauthenticated
            } else {
                errorMessage = error.localizedDescription
                authState = .unauthenticated
            }
            return
        }

        guard
            let url,
            let components = URLComponents(url: url, resolvingAgainstBaseURL: false),
            let code = components.queryItems?.first(where: { $0.name == "code" })?.value,
            let verifier = codeVerifier
        else {
            errorMessage = "Invalid callback URL"
            authState = .unauthenticated
            return
        }

        await exchangeCodeForTokens(code: code, verifier: verifier)
    }

    private func exchangeCodeForTokens(code: String, verifier: String) async {
        var request = URLRequest(url: URL(string: "https://accounts.spotify.com/api/token")!)
        request.httpMethod = "POST"
        request.setValue("application/x-www-form-urlencoded", forHTTPHeaderField: "Content-Type")
        request.httpBody = formEncoded([
            "client_id": clientID,
            "grant_type": "authorization_code",
            "code": code,
            "redirect_uri": redirectURI,
            "code_verifier": verifier
        ])

        do {
            let (data, _) = try await URLSession.shared.data(for: request)
            let response = try JSONDecoder().decode(TokenResponse.self, from: data)
            guard let refreshToken = response.refresh_token else {
                throw URLError(.badServerResponse)
            }
            TokenStore.shared.save(accessToken: response.access_token, refreshToken: refreshToken)
            authState = .authenticated
        } catch {
            errorMessage = "Login failed. Please try again."
            authState = .unauthenticated
        }
    }

    // MARK: - PKCE Helpers

    private func generateCodeVerifier() -> String {
        var bytes = [UInt8](repeating: 0, count: 64)
        _ = SecRandomCopyBytes(kSecRandomDefault, bytes.count, &bytes)
        return Data(bytes).base64URLEncoded()
    }

    private func generateCodeChallenge(from verifier: String) -> String {
        let digest = SHA256.hash(data: Data(verifier.utf8))
        return Data(digest).base64URLEncoded()
    }

    private func formEncoded(_ params: [String: String]) -> Data? {
        params
            .map { "\($0.key)=\($0.value.addingPercentEncoding(withAllowedCharacters: .urlQueryAllowed) ?? "")" }
            .joined(separator: "&")
            .data(using: .utf8)
    }
}

// MARK: - ASWebAuthenticationPresentationContextProviding

extension SpotifyAuthManager: ASWebAuthenticationPresentationContextProviding {
    nonisolated func presentationAnchor(for session: ASWebAuthenticationSession) -> ASPresentationAnchor {
        let scenes = UIApplication.shared.connectedScenes.compactMap { $0 as? UIWindowScene }
        let activeScene = scenes.first(where: {
            $0.activationState == .foregroundActive || $0.activationState == .foregroundInactive
        }) ?? scenes.first
        return activeScene?.windows.first(where: \.isKeyWindow)
            ?? activeScene?.windows.first
            ?? UIWindow()
    }
}

// MARK: - Models

private struct TokenResponse: Decodable {
    let access_token: String
    let refresh_token: String?
    let expires_in: Int
}

// MARK: - Data Helpers

private extension Data {
    func base64URLEncoded() -> String {
        base64EncodedString()
            .replacingOccurrences(of: "+", with: "-")
            .replacingOccurrences(of: "/", with: "_")
            .replacingOccurrences(of: "=", with: "")
    }
}
