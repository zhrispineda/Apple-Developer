//
//  CloudKeyValueStore.swift
//  Developer
//

import Foundation

/// The subset of `NSUbiquitousKeyValueStore` the sync stores rely on, so tests
/// can substitute an in-memory store instead of writing to the user's iCloud.
protocol CloudKeyValueStore: AnyObject {
    func set(_ value: Any?, forKey key: String)
    func data(forKey key: String) -> Data?
    func array(forKey key: String) -> [Any]?
    @discardableResult func synchronize() -> Bool
}

extension NSUbiquitousKeyValueStore: CloudKeyValueStore {}
