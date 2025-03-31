// MARK: - QueryContext

public struct QueryContext: Sendable {
  private var storage = LockedBox(value: [StorageKey: any Sendable]())

  public init() {}
}

// MARK: - Storage

extension QueryContext {
  private struct StorageKey: Hashable {
    let id: ObjectIdentifier
    let typeName: String

    init(type: Any.Type) {
      self.id = ObjectIdentifier(type)
      self.typeName = Query.typeName(type)
    }
  }
}

// MARK: - QueryContextKey

extension QueryContext {
  public protocol Key<Value> {
    associatedtype Value: Sendable

    static var defaultValue: Value { get }
  }
}

// MARK: - Subscript

extension QueryContext {
  public subscript<Value>(_ key: (some Key<Value>).Type) -> Value {
    get {
      self.storage.inner.withLock { entries in
        let storageKey = StorageKey(type: key)
        if let value = entries[storageKey] as? Value {
          return value
        }
        let defaultValue = key.defaultValue
        entries[storageKey] = defaultValue
        return defaultValue
      }
    }
    set {
      var storage: LockedBox<[StorageKey: any Sendable]>
      defer { self.storage = storage }
      if !isKnownUniquelyReferenced(&self.storage) {
        storage = LockedBox<[StorageKey: any Sendable]>(
          value: self.storage.inner.withLock { $0 }
        )
      } else {
        storage = self.storage
      }
      storage.inner.withLock { $0[StorageKey(type: key)] = newValue }
    }
  }
}

// MARK: - CustomStringConvertible

extension QueryContext: CustomStringConvertible {
  public var description: String {
    self.storage.inner.withLock {
      let string = $0.map { (key, value) in "\(key.typeName) = \(value)" }.joined(separator: ", ")
      return "[\(string)]"
    }
  }
}
