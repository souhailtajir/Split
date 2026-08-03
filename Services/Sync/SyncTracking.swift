//
//  SyncTracking.swift
//  Split
//
//  Created by Souhail on 8/3/26.
//

import Foundation

/// Common tracking for local-first, peer-to-peer sync.
/// Models conforming to this protocol must provide a unique `id` and a set of
/// metadata fields used to detect and merge concurrent changes.
public protocol LocalMutationTrackable: AnyObject {
    // Stable identity
    var id: UUID { get }

    // Mutation tracking
    var createdAt: Date { get set }
    var updatedAt: Date { get set }
    var lastModifiedByDeviceID: String? { get set }
    var changeCounter: Int { get set }
    var isTombstoned: Bool { get set }
}

public extension LocalMutationTrackable {
    /// Marks the model as changed locally. Call this from mutation sites that
    /// alter user-visible data. Runs on the main actor to align with SwiftData usage.
    @MainActor
    func markChanged(by deviceID: String? = nil, at date: Date = .now) {
        updatedAt = date
        if let deviceID {
            lastModifiedByDeviceID = deviceID
        }
        changeCounter &+= 1
    }

    /// Marks the model as logically deleted while preserving a tombstone for sync.
    @MainActor
    func markDeleted(by deviceID: String? = nil, at date: Date = .now) {
        isTombstoned = true
        markChanged(by: deviceID, at: date)
    }
}
