//
//  TokenStore.swift
//  Dalmation
//
//  Created by Benjamin Parsons on 3/8/26.
//

import Foundation
import Security

final class TokenStore {

    static let shared = TokenStore()
    private init() {}

    private let accessTokenKey = "spotify_access_token"
    private let refreshTokenKey = "spotify_refresh_token"

    var accessToken: String? { read(key: accessTokenKey) }
    var refreshToken: String? { read(key: refreshTokenKey) }

    func save(accessToken: String, refreshToken: String) {
        write(key: accessTokenKey, value: accessToken)
        write(key: refreshTokenKey, value: refreshToken)
    }

    func clearTokens() {
        delete(key: accessTokenKey)
        delete(key: refreshTokenKey)
    }

    // MARK: - Keychain

    private func write(key: String, value: String) {
        guard let data = value.data(using: .utf8) else { return }
        delete(key: key)
        let query: [String: Any] = [
            kSecClass as String: kSecClassGenericPassword,
            kSecAttrAccount as String: key,
            kSecValueData as String: data,
            kSecAttrAccessible as String: kSecAttrAccessibleAfterFirstUnlock
        ]
        SecItemAdd(query as CFDictionary, nil)
    }

    private func read(key: String) -> String? {
        let query: [String: Any] = [
            kSecClass as String: kSecClassGenericPassword,
            kSecAttrAccount as String: key,
            kSecReturnData as String: true,
            kSecMatchLimit as String: kSecMatchLimitOne
        ]
        var result: AnyObject?
        SecItemCopyMatching(query as CFDictionary, &result)
        guard let data = result as? Data else { return nil }
        return String(data: data, encoding: .utf8)
    }

    private func delete(key: String) {
        let query: [String: Any] = [
            kSecClass as String: kSecClassGenericPassword,
            kSecAttrAccount as String: key
        ]
        SecItemDelete(query as CFDictionary)
    }
}
