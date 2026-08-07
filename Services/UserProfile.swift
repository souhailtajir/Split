//
//  UserProfile.swift
//  Split
//
//  Created by Souhail on 8/6/26.
//

import Foundation

/// A lightweight, device-local user profile backed by `UserDefaults`.
///
/// Stores the current user's display name and handle so they can be
/// automatically added as the creator/owner of every new group.
@Observable @MainActor
final class UserProfile: Sendable {
  // MARK: - Singleton

  static let shared = UserProfile()

  // MARK: - Persisted Properties

  var displayName: String {
    didSet { UserDefaults.standard.set(displayName, forKey: Keys.displayName) }
  }

  var handle: String {
    didSet { UserDefaults.standard.set(handle, forKey: Keys.handle) }
  }

  var isProfileSetUp: Bool {
    didSet { UserDefaults.standard.set(isProfileSetUp, forKey: Keys.isProfileSetUp) }
  }

  // MARK: - Init

  private init() {
    self.displayName = UserDefaults.standard.string(forKey: Keys.displayName) ?? ""
    self.handle = UserDefaults.standard.string(forKey: Keys.handle) ?? ""
    self.isProfileSetUp = UserDefaults.standard.bool(forKey: Keys.isProfileSetUp)
  }

  // MARK: - Keys

  private enum Keys {
    static let displayName = "user_display_name"
    static let handle = "user_handle"
    static let isProfileSetUp = "user_profile_set_up"
  }
}
