import Dependencies
import Foundation
import KeychainSwift
import Synchronization

// MARK: - SecureStorage

public protocol SecureStorage: Sendable {
  subscript(key: String) -> Data? { get set }
}

// MARK: - KeychainSecureStorage

// NB: KeychainSwift's operations are thread-safe, but some of its member variables are not. Since
// we're not touching the member variables, we can mark this class as @unchecked Sendable.
public final class KeychainSecureStorage: SecureStorage, @unchecked Sendable {
  private let keychain = KeychainSwift()

  public init() {}

  public subscript(key: String) -> Data? {
    get { self.keychain.getData(key) }
    set {
      if let newValue {
        self.keychain.set(newValue, forKey: key)
      } else {
        self.keychain.delete(key)
      }
    }
  }
}

// MARK: - InMemorySecureStorage

public final class InMemorySecureStorage: SecureStorage {
  private let storage = Mutex([String: Data]())

  public init() {}

  public subscript(key: String) -> Data? {
    get { self.storage.withLock { $0[key] } }
    set {
      if let newValue {
        self.storage.withLock { $0[key] = newValue }
      } else {
        _ = self.storage.withLock { $0.removeValue(forKey: key) }
      }
    }
  }
}

// MARK: - SecureStorageKey

public enum SecureStorageKey: DependencyKey {
  public static let liveValue: any SecureStorage = KeychainSecureStorage()
  public static let testValue: any SecureStorage = InMemorySecureStorage()
}
